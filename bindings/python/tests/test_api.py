import gc
import unittest
import weakref

import zeft


class RenderingTests(unittest.TestCase):
    def test_render_common_values_and_nested_context(self):
        with zeft.compile(
            "{{ name }}:{{ enabled }}:{{ count }}:{{ ratio }}:{{ nothing }}:"
            "{{ user.name }}:{{ values[1] }}"
        ) as template:
            result = template.render(
                {
                    "name": "Zeft",
                    "enabled": True,
                    "count": 42,
                    "ratio": 1.5,
                    "nothing": None,
                    "user": {"name": "nested"},
                    "values": ["zero", "one"],
                }
            )
        self.assertEqual(result, "Zeft:true:42:1.5::nested:one")

    def test_html_escaping(self):
        template = zeft.compile('<p title="{{ value }}">text</p>')
        self.assertEqual(
            template.render({"value": '<&>"\''}),
            '<p title="&lt;&amp;&gt;&quot;&#39;">text</p>',
        )
        template.close()

    def test_compile_and_render_diagnostics(self):
        with self.assertRaises(zeft.CompileError) as compile_error:
            zeft.compile("{#if value}")
        self.assertTrue(compile_error.exception.kind)
        self.assertIsNotNone(compile_error.exception.span)

        template = zeft.compile("{{ missing }}")
        with self.assertRaises(zeft.RenderError) as render_error:
            template.render({})
        self.assertEqual(render_error.exception.kind, "missing_variable")
        self.assertIsNotNone(render_error.exception.span)
        template.close()

    def test_context_validation_and_integer_range(self):
        template = zeft.compile("{{ value }}")
        with self.assertRaises(TypeError):
            template.render({"value": b"no"})
        with self.assertRaises(TypeError):
            template.render(["not", "a", "mapping"])
        with self.assertRaises(OverflowError):
            template.render({"value": 2**63})
        template.close()

    def test_close_is_idempotent_and_releases_native_template(self):
        template = zeft.compile("Hello")
        native = template._native_template
        reference = weakref.ref(native)
        del native
        template.close()
        template.close()
        gc.collect()
        self.assertIsNone(reference())
        with self.assertRaises(ValueError):
            template.render({})

    def test_context_manager_closes_template(self):
        with zeft.compile("ok") as template:
            self.assertEqual(template.render({}), "ok")
        with self.assertRaises(ValueError):
            template.render({})


class SafetyTests(unittest.TestCase):
    def test_nested_conversion_errors_clean_up_once(self):
        with zeft.compile("{{ value }}") as template:
            for value in ([object()], {"nested": object()}, [{"nested": b"no"}]):
                with self.subTest(value=value), self.assertRaises(TypeError):
                    template.render({"value": value})
            cycle = []
            cycle.append(cycle)
            with self.assertRaises(ValueError):
                template.render({"value": cycle})
            self.assertEqual(template.render({"value": "ok"}), "ok")

    def test_temporary_mapping_and_sequence_strings_are_owned(self):
        class Mapping:
            def __getitem__(self, key):
                raise KeyError(key)

            def items(self):
                return [("value", "".join(["A"] * 80))]

        class Sequence(list):
            def __getitem__(self, index):
                return "".join(["A"] * 80)

        with zeft.compile("{{ obj.value }}|{{ values[0] }}") as template:
            self.assertEqual(
                template.render({"obj": Mapping(), "values": Sequence([None])}),
                "A" * 80 + "|" + "A" * 80,
            )

    def test_malformed_mapping_items_raise_type_error(self):
        class Mapping:
            def __getitem__(self, key):
                raise KeyError(key)

            def items(self):
                return [("value",)]

        with zeft.compile("{{ value }}") as template:
            with self.assertRaises(TypeError):
                template.render(Mapping())

    def test_native_options_are_checked_and_default_indentation_lives_through_compile(self):
        from zeft import _native

        for format, whitespace in ((-1, 0), (2, 0), (0, -1), (0, 3), (2**32, 0)):
            with self.assertRaises((ValueError, OverflowError)):
                _native.compile("ok", format, whitespace)
        template = _native.compile("<a><b></b></a>", 0, 2)
        self.assertEqual(template.render({}), "<a>\n  <b></b>\n</a>\n")

    def test_executable_html_interpolation_is_rejected(self):
        for source in (
            '<script>const x="{{ value }}";</script>',
            '<style>{{ value }}</style>',
            '<p onclick="{{ value }}">ok</p>',
        ):
            with self.subTest(source=source), self.assertRaises(zeft.CompileError) as error:
                zeft.compile(source)
            self.assertEqual(error.exception.kind, "unsupported_syntax")

    def test_deep_expressions_raise_compile_error(self):
        source = "{{" + "(" * 20000 + "1" + ")" * 20000 + "}}"
        with self.assertRaises(zeft.CompileError) as error:
            zeft.compile(source)
        self.assertEqual(error.exception.kind, "unsupported_syntax")


if __name__ == "__main__":
    unittest.main()
