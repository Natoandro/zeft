#define PY_SSIZE_T_CLEAN
#include <Python.h>

typedef struct {
    PyObject_HEAD
    void *compiled;
} ZeftTemplate;

extern int zeft_template_compile(const char *, size_t, void **);
extern void zeft_template_release(void *);

static void template_dealloc(ZeftTemplate *self) {
    zeft_template_release(self->compiled);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

static PyTypeObject ZeftTemplateType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    .tp_name = "zeft._native.Template",
    .tp_basicsize = sizeof(ZeftTemplate),
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "Owns a compiled Zeft template.",
    .tp_dealloc = (destructor)template_dealloc,
};

static PyObject *module_compile(PyObject *module, PyObject *source) {
    (void)module;
    if (!PyUnicode_Check(source)) {
        PyErr_SetString(PyExc_TypeError, "source must be str");
        return NULL;
    }

    Py_ssize_t source_len = 0;
    const char *source_bytes = PyUnicode_AsUTF8AndSize(source, &source_len);
    if (source_bytes == NULL) return NULL;

    ZeftTemplate *result = PyObject_New(ZeftTemplate, &ZeftTemplateType);
    if (result == NULL) return NULL;
    result->compiled = NULL;

    const int status = zeft_template_compile(
        source_bytes,
        (size_t)source_len,
        &result->compiled
    );
    if (status != 0) {
        Py_DECREF(result);
        if (status < 0) return PyErr_NoMemory();
        PyErr_SetString(PyExc_ValueError, "template compilation failed");
        return NULL;
    }
    return (PyObject *)result;
}

static PyMethodDef module_methods[] = {
    {"compile", module_compile, METH_O, "Compile source into an owning template."},
    {NULL, NULL, 0, NULL},
};

static struct PyModuleDef module_definition = {
    PyModuleDef_HEAD_INIT,
    .m_name = "zeft._native",
    .m_doc = "Native CPython bridge for Zeft.",
    .m_size = -1,
    .m_methods = module_methods,
};

PyMODINIT_FUNC PyInit__native(void) {
    if (PyType_Ready(&ZeftTemplateType) < 0) return NULL;

    PyObject *module = PyModule_Create(&module_definition);
    if (module == NULL) return NULL;
    Py_INCREF(&ZeftTemplateType);
    if (PyModule_AddObject(
            module,
            "Template",
            (PyObject *)&ZeftTemplateType
        ) < 0) {
        Py_DECREF(&ZeftTemplateType);
        Py_DECREF(module);
        return NULL;
    }
    return module;
}
