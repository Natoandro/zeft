#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

/* Keep these tags and status values in sync with module.zig's C ABI. */
enum {
    VALUE_NULL = 0,
    VALUE_BOOLEAN,
    VALUE_INTEGER,
    VALUE_FLOAT,
    VALUE_STRING,
    VALUE_OBJECT,
    VALUE_SEQUENCE
};

enum {
    STATUS_ERROR = -1,
    STATUS_OK = 0,
    STATUS_DIAGNOSTIC = 1
};

enum {
    FORMAT_HTML = 0,
    WHITESPACE_PRESERVE = 0,
    MAX_CONTEXT_DEPTH = 128,
    MAX_TYPE_NAME_LENGTH = 200,
    C_STRING_TERMINATOR_SIZE = 1,
    EMPTY_ALLOCATION_COUNT = 1,
    DIAGNOSTIC_ARGUMENT_COUNT = 3,
    MAPPING_KEY_INDEX = 0,
    MAPPING_VALUE_INDEX = 1,
    NO_OVERFLOW = 0,
    ERROR_SENTINEL = -1,
    MODULE_GLOBAL_STATE_SIZE = -1,
    NO_METHOD_FLAGS = 0
};

typedef struct ZeftValue {
    int tag;
    int boolean;
    int64_t integer;
    double number;
    const char *data;
    size_t len;
    struct ZeftValue *children;
    struct ZeftBytes *keys;
} ZeftValue;
typedef struct ZeftBytes { const char *data; size_t len; } ZeftBytes;
typedef struct { int present; size_t start; size_t end; } ZeftSpan;
typedef struct { PyObject_HEAD void *compiled; PyObject *weakrefs; } ZeftTemplate;

extern int zeft_template_compile(const char *, size_t, int, int, const char *,
                                 size_t, void **, int *, ZeftSpan *);
extern int zeft_template_render(void *, const ZeftValue *, char **, size_t *,
                                int *, ZeftSpan *);
extern void zeft_buffer_release(char *, size_t);
extern void zeft_template_release(void *);

static PyObject *CompileDiagnostic;
static PyObject *RenderDiagnostic;
static PyTypeObject ZeftTemplateType;

static void free_value(ZeftValue *value) {
    if (value->tag == VALUE_OBJECT || value->tag == VALUE_SEQUENCE) {
        for (size_t i = 0; i < value->len; i++) {
            free_value(&value->children[i]);
            if (value->tag == VALUE_OBJECT) free((void *)value->keys[i].data);
        }
        free(value->children);
        free(value->keys);
    }
}

static int convert_value(PyObject *object, ZeftValue *out, int depth) {
    memset(out, 0, sizeof(*out));
    if (depth > MAX_CONTEXT_DEPTH) {
        PyErr_Format(PyExc_ValueError, "context nesting exceeds %d levels",
                     MAX_CONTEXT_DEPTH);
        return STATUS_ERROR;
    }
    if (object == Py_None) { out->tag = VALUE_NULL; return STATUS_OK; }
    if (PyBool_Check(object)) {
        out->tag = VALUE_BOOLEAN; out->boolean = object == Py_True; return STATUS_OK;
    }
    if (PyLong_Check(object)) {
        int overflow = NO_OVERFLOW;
        long long number = PyLong_AsLongLongAndOverflow(object, &overflow);
        if (overflow) {
            PyErr_SetString(PyExc_OverflowError, "integer does not fit signed 64-bit range");
            return STATUS_ERROR;
        }
        if (PyErr_Occurred()) return STATUS_ERROR;
        out->tag = VALUE_INTEGER; out->integer = (int64_t)number; return STATUS_OK;
    }
    if (PyFloat_Check(object)) {
        out->tag = VALUE_FLOAT; out->number = PyFloat_AS_DOUBLE(object); return STATUS_OK;
    }
    if (PyUnicode_Check(object)) {
        Py_ssize_t length;
        const char *data = PyUnicode_AsUTF8AndSize(object, &length);
        if (!data) return STATUS_ERROR;
        out->tag = VALUE_STRING; out->data = data; out->len = (size_t)length;
        return STATUS_OK;
    }
    if (PyList_Check(object) || PyTuple_Check(object)) {
        Py_ssize_t count = PySequence_Size(object);
        if (count == ERROR_SENTINEL) return STATUS_ERROR;
        out->tag = VALUE_SEQUENCE; out->len = (size_t)count;
        out->children = calloc(out->len ? out->len : EMPTY_ALLOCATION_COUNT,
                               sizeof(ZeftValue));
        if (!out->children) { PyErr_NoMemory(); return STATUS_ERROR; }
        for (size_t i = 0; i < out->len; i++) {
            PyObject *child = PySequence_GetItem(object, (Py_ssize_t)i);
            if (!child || convert_value(child, &out->children[i], depth + 1) <
                              STATUS_OK) {
                Py_XDECREF(child); free_value(out); return STATUS_ERROR;
            }
            Py_DECREF(child);
        }
        return STATUS_OK;
    }
    if (PyMapping_Check(object) && !PyBytes_Check(object) &&
        !PyByteArray_Check(object)) {
        PyObject *items = PyMapping_Items(object);
        if (!items) return STATUS_ERROR;
        Py_ssize_t count = PyList_Size(items);
        if (count == ERROR_SENTINEL) { Py_DECREF(items); return STATUS_ERROR; }
        out->tag = VALUE_OBJECT; out->len = (size_t)count;
        size_t allocation_count = out->len ? out->len : EMPTY_ALLOCATION_COUNT;
        out->children = calloc(allocation_count, sizeof(ZeftValue));
        out->keys = calloc(allocation_count, sizeof(ZeftBytes));
        if (!out->children || !out->keys) {
            Py_DECREF(items); free_value(out); PyErr_NoMemory(); return STATUS_ERROR;
        }
        for (size_t i = 0; i < out->len; i++) {
            PyObject *pair = PyList_GetItem(items, (Py_ssize_t)i);
            PyObject *key = PyTuple_GetItem(pair, MAPPING_KEY_INDEX);
            PyObject *child = PyTuple_GetItem(pair, MAPPING_VALUE_INDEX);
            if (!PyUnicode_Check(key)) {
                PyErr_SetString(PyExc_TypeError, "mapping keys must be strings");
                Py_DECREF(items); free_value(out); return STATUS_ERROR;
            }
            Py_ssize_t key_len;
            const char *key_data = PyUnicode_AsUTF8AndSize(key, &key_len);
            if (!key_data) { Py_DECREF(items); free_value(out); return STATUS_ERROR; }
            char *key_copy = malloc((size_t)key_len + C_STRING_TERMINATOR_SIZE);
            if (!key_copy) {
                Py_DECREF(items); free_value(out); PyErr_NoMemory(); return STATUS_ERROR;
            }
            memcpy(key_copy, key_data, (size_t)key_len);
            key_copy[key_len] = '\0';
            out->keys[i] = (ZeftBytes){ key_copy, (size_t)key_len };
            if (convert_value(child, &out->children[i], depth + 1) < STATUS_OK) {
                Py_DECREF(items); free_value(out); return STATUS_ERROR;
            }
        }
        Py_DECREF(items);
        return STATUS_OK;
    }
    PyErr_Format(PyExc_TypeError, "unsupported context value type: %.*s",
                 MAX_TYPE_NAME_LENGTH, Py_TYPE(object)->tp_name);
    return STATUS_ERROR;
}

static PyObject *diagnostic_error(PyObject *exception, const char *const *kinds,
                                  size_t kind_count, int kind, ZeftSpan span) {
    const char *name = kind >= STATUS_OK && (size_t)kind < kind_count
                           ? kinds[kind] : "unknown";
    PyObject *kind_obj = PyUnicode_FromString(name);
    PyObject *start = span.present ? PyLong_FromSize_t(span.start) : Py_NewRef(Py_None);
    PyObject *end = span.present ? PyLong_FromSize_t(span.end) : Py_NewRef(Py_None);
    if (!kind_obj || !start || !end) {
        Py_XDECREF(kind_obj); Py_XDECREF(start); Py_XDECREF(end); return NULL;
    }
    PyObject *args = PyTuple_Pack(DIAGNOSTIC_ARGUMENT_COUNT, kind_obj, start, end);
    Py_DECREF(kind_obj); Py_DECREF(start); Py_DECREF(end);
    if (!args) return NULL;
    PyErr_SetObject(exception, args);
    Py_DECREF(args);
    return NULL;
}

static const char *const compile_kinds[] = {
    "syntax", "invalid_markup", "invalid_expression", "invalid_construct",
    "unsupported_syntax"
};
static const size_t compile_kind_count = sizeof(compile_kinds) / sizeof(compile_kinds[0]);
static const char *const render_kinds[] = {
    "missing_variable", "invalid_property_access", "invalid_operand", "non_iterable",
    "filter_failure", "function_failure", "writer_failure", "missing_template",
    "missing_include", "include_cycle", "include_compile_failure"
};
static const size_t render_kind_count = sizeof(render_kinds) / sizeof(render_kinds[0]);

static void template_dealloc(ZeftTemplate *self) {
    if (self->weakrefs) PyObject_ClearWeakRefs((PyObject *)self);
    zeft_template_release(self->compiled);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

static PyObject *module_compile(PyObject *module, PyObject *args, PyObject *kwargs) {
    (void)module;
    static char *names[] = {"source", "format", "whitespace", "indentation", NULL};
    PyObject *source, *format_obj = NULL, *whitespace_obj = NULL, *indent_obj = NULL;
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O|OOO:compile", names,
                                     &source, &format_obj, &whitespace_obj, &indent_obj))
        return NULL;
    if (!PyUnicode_Check(source)) {
        PyErr_SetString(PyExc_TypeError, "source must be str"); return NULL;
    }
    int format = format_obj ? (int)PyLong_AsLong(format_obj) : FORMAT_HTML;
    int whitespace = whitespace_obj ? (int)PyLong_AsLong(whitespace_obj) :
                                      WHITESPACE_PRESERVE;
    if (PyErr_Occurred()) return NULL;
    PyObject *indent = indent_obj ? indent_obj : PyUnicode_FromString("  ");
    if (!indent) return NULL;
    if (!PyUnicode_Check(indent)) {
        if (!indent_obj) Py_DECREF(indent);
        PyErr_SetString(PyExc_TypeError, "indentation must be str"); return NULL;
    }
    Py_ssize_t source_len, indent_len;
    const char *source_data = PyUnicode_AsUTF8AndSize(source, &source_len);
    const char *indent_data = PyUnicode_AsUTF8AndSize(indent, &indent_len);
    if (!indent_obj) Py_DECREF(indent);
    if (!source_data || !indent_data) return NULL;
    ZeftTemplate *result = PyObject_New(ZeftTemplate, &ZeftTemplateType);
    if (!result) return NULL;
    result->compiled = NULL;
    result->weakrefs = NULL;
    int kind = STATUS_OK; ZeftSpan span = {0};
    int status = zeft_template_compile(source_data, (size_t)source_len, format,
        whitespace, indent_data, (size_t)indent_len, &result->compiled, &kind, &span);
    if (status != STATUS_OK) {
        Py_DECREF(result);
        if (status == STATUS_ERROR) return PyErr_NoMemory();
        return diagnostic_error(CompileDiagnostic, compile_kinds, compile_kind_count,
                                kind, span);
    }
    return (PyObject *)result;
}

static PyObject *template_render(ZeftTemplate *self, PyObject *context) {
    if (!PyMapping_Check(context) || PyBytes_Check(context) ||
        PyByteArray_Check(context) || PyList_Check(context) || PyTuple_Check(context)) {
        PyErr_SetString(PyExc_TypeError, "context must be a mapping"); return NULL;
    }
    ZeftValue value;
    if (convert_value(context, &value, STATUS_OK) == STATUS_ERROR) return NULL;
    char *output = NULL; size_t output_len = 0; int kind = STATUS_OK;
    ZeftSpan span = {0};
    int status = zeft_template_render(self->compiled, &value, &output, &output_len,
                                      &kind, &span);
    free_value(&value);
    if (status == STATUS_ERROR) return PyErr_NoMemory();
    if (status == STATUS_DIAGNOSTIC) {
        return diagnostic_error(RenderDiagnostic, render_kinds, render_kind_count,
                                kind, span);
    }
    PyObject *result = PyUnicode_DecodeUTF8(output, (Py_ssize_t)output_len, "strict");
    zeft_buffer_release(output, output_len);
    return result;
}

static PyMethodDef template_methods[] = {
    {"render", (PyCFunction)template_render, METH_O, "Render with a mapping context."},
    {NULL, NULL, NO_METHOD_FLAGS, NULL}
};
static PyMethodDef module_methods[] = {
    {"compile", (PyCFunction)(void(*)(void))module_compile,
     METH_VARARGS | METH_KEYWORDS, "Compile source into an owning template."},
    {NULL, NULL, NO_METHOD_FLAGS, NULL}
};
static struct PyModuleDef module_definition = {
    PyModuleDef_HEAD_INIT, .m_name = "zeft._native",
    .m_doc = "Native CPython bridge for Zeft.",
    .m_size = MODULE_GLOBAL_STATE_SIZE,
    .m_methods = module_methods
};

static PyTypeObject ZeftTemplateType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "zeft._native.Template", .tp_basicsize = sizeof(ZeftTemplate),
    .tp_flags = Py_TPFLAGS_DEFAULT, .tp_doc = "Owns a compiled Zeft template.",
    .tp_dealloc = (destructor)template_dealloc, .tp_methods = template_methods,
    .tp_weaklistoffset = offsetof(ZeftTemplate, weakrefs)
};

PyMODINIT_FUNC PyInit__native(void) {
    if (PyType_Ready(&ZeftTemplateType) < 0) return NULL;
    PyObject *module = PyModule_Create(&module_definition);
    if (!module) return NULL;
    CompileDiagnostic = PyErr_NewException("zeft._native.CompileDiagnostic", PyExc_Exception, NULL);
    RenderDiagnostic = PyErr_NewException("zeft._native.RenderDiagnostic", PyExc_Exception, NULL);
    if (!CompileDiagnostic || !RenderDiagnostic ||
        PyModule_AddObjectRef(module, "CompileDiagnostic", CompileDiagnostic) < 0 ||
        PyModule_AddObjectRef(module, "RenderDiagnostic", RenderDiagnostic) < 0) {
        Py_XDECREF(CompileDiagnostic); Py_XDECREF(RenderDiagnostic); Py_DECREF(module); return NULL;
    }
    Py_INCREF(&ZeftTemplateType);
    if (PyModule_AddObject(module, "Template", (PyObject *)&ZeftTemplateType) < 0) {
        Py_DECREF(&ZeftTemplateType); Py_DECREF(module); return NULL;
    }
    return module;
}
