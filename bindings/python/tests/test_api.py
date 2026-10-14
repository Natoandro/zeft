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


if __name__ == "__main__":
    unittest.main()
