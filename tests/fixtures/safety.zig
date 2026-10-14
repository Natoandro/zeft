//! Safety regression suite registrations and reusable inputs.
pub const harness_ids = [_][]const u8{
    "S-001", "S-002", "S-003", "S-004", "S-005", "S-006", "S-007", "S-008", "S-009", "O-003",
};
pub const executable_html = [_][]const u8{
    "<script>let x=\"{{ value }}\";</script>",
    "<STYLE>{{ value }}</STYLE>",
    "<button OnClick=\"{{ value }}\">ok</button>",
    "<div STYLE=\"{{ value }}\"></div>",
    "<iframe srcdoc=\"{{ value }}\"></iframe>",
    "<script>{#if true}{{ value }}{/if}</script>",
};
pub const malformed_xml = [_][]const u8{
    "<x a='1' a='2'/>", "<x 1='2'/>",                       "<x a?='2'/>", "<x>\x00</x>",
    "<x>\xff</x>",      "<?xml version='1.1'?><x>\x01</x>",
};
pub const invalid_logical = [_][]const u8{
    "{{ true && 123 }}",      "{{ false || 123 }}",         "{{ true && null }}",
    "{{ false || 'value' }}", "{{ true && (false || 1) }}",
};
