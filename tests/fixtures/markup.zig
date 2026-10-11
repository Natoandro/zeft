//! Byte-exact successful markup fixtures.
const fixtures = @import("../fixture_runner.zig");

pub const compile_failure_cases = [_]fixtures.CompileFailure{
    .{
        .id = "MK-052",
        .template = "<div/>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 6,
            },
        },
    },
    .{
        .id = "MK-053",
        .template = "</BR>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 5,
            },
        },
    },
    .{
        .id = "MK-054",
        .template = "<!-- text",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 9,
            },
        },
    },
    .{
        .id = "MK-055",
        .template = "<!DOCTYPE svg>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 14,
            },
        },
    },
    .{
        .id = "MK-056",
        .template = "<?target?>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 10,
            },
        },
    },
    .{
        .id = "MK-057",
        .template = "<![CDATA[x]]>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 13,
            },
        },
    },
    .{
        .id = "MK-058",
        .template = "<Root></root>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 6,
                .end = 13,
            },
        },
    },
    .{
        .id = "MK-059",
        .template = "<n checked/>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 12,
            },
        },
    },
    .{
        .id = "MK-060",
        .template = "<n a=value/>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 12,
            },
        },
    },
    .{
        .id = "MK-061",
        .template = "<!-- a--b -->",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 8,
            },
        },
    },
    .{
        .id = "MK-062",
        .template = "<![CDATA[text",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 13,
            },
        },
    },
    .{
        .id = "MK-063",
        .template = "<!DOCTYPE root>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 15,
            },
        },
    },
    .{
        .id = "MK-064",
        .template = "<?target?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 10,
            },
        },
    },
    .{
        .id = "MK-065",
        .template = "&custom;",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 1,
            },
        },
    },
    .{
        .id = "MK-066",
        .template = "&#0;",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 1,
            },
        },
    },
    .{
        .id = "MK-067",
        .template = "&#xD800;",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 1,
            },
        },
    },
    .{
        .id = "MK-068",
        .template = "x]]>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 1,
                .end = 4,
            },
        },
    },
    .{
        .id = "MK-069",
        .template = "<n a='x<y'/>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 12,
            },
        },
    },
    .{
        .id = "MK-070",
        .template = "<n a='&custom;'/>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 17,
            },
        },
    },
    .{
        .id = "MK-071",
        .template = "x<?xml version=\"1.0\"?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 1,
                .end = 22,
            },
        },
    },
    .{
        .id = "MK-072",
        .template = "<?xml version=\"2.0\"?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 21,
            },
        },
    },
};

pub const Context = struct { value: []const u8 };
pub const SuccessCase = struct { fixture: fixtures.Success, params: Context };

pub const success_cases = [_]SuccessCase{
    .{
        .fixture = .{
            .id = "MK-001",
            .template = "<area>",
            .output = "<area>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-002",
            .template = "<area/>",
            .output = "<area/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-003",
            .template = "<base>",
            .output = "<base>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-004",
            .template = "<base/>",
            .output = "<base/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-005",
            .template = "<br>",
            .output = "<br>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-006",
            .template = "<br/>",
            .output = "<br/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-007",
            .template = "<col>",
            .output = "<col>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-008",
            .template = "<col/>",
            .output = "<col/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-009",
            .template = "<embed>",
            .output = "<embed>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-010",
            .template = "<embed/>",
            .output = "<embed/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-011",
            .template = "<hr>",
            .output = "<hr>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-012",
            .template = "<hr/>",
            .output = "<hr/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-013",
            .template = "<img>",
            .output = "<img>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-014",
            .template = "<img/>",
            .output = "<img/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-015",
            .template = "<input>",
            .output = "<input>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-016",
            .template = "<input/>",
            .output = "<input/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-017",
            .template = "<link>",
            .output = "<link>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-018",
            .template = "<link/>",
            .output = "<link/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-019",
            .template = "<meta>",
            .output = "<meta>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-020",
            .template = "<meta/>",
            .output = "<meta/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-021",
            .template = "<param>",
            .output = "<param>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-022",
            .template = "<param/>",
            .output = "<param/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-023",
            .template = "<source>",
            .output = "<source>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-024",
            .template = "<source/>",
            .output = "<source/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-025",
            .template = "<track>",
            .output = "<track>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-026",
            .template = "<track/>",
            .output = "<track/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-027",
            .template = "<wbr>",
            .output = "<wbr>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-028",
            .template = "<wbr/>",
            .output = "<wbr/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-029",
            .template = "<ArEa><bAsE/><BR><CoL/><EmBeD><Hr/><ImG><InPuT/><LiNk><MeTa/><PaRaM><SoUrCe/><TrAcK><WbR/>",
            .output = "<ArEa><bAsE/><BR><CoL/><EmBeD><Hr/><ImG><InPuT/><LiNk><MeTa/><PaRaM><SoUrCe/><TrAcK><WbR/>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-030",
            .template = "<Main><Child ID = 'x'>text</cHiLd></MAIN>",
            .output = "<Main><Child ID = 'x'>text</cHiLd></MAIN>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-031",
            .template = "<input DISABLED checked='' readonly='false' required=\"required\" autofocus />",
            .output = "<input DISABLED checked='' readonly='false' required=\"required\" autofocus />",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-032",
            .template = "before{{ value }}after",
            .output = "before&amp;&lt;&gt;\"'after",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-033",
            .template = "<node attr=\"prefix{{ value }}middle{{ value }}suffix\"></node>",
            .output = "<node attr=\"prefix&amp;&lt;&gt;&quot;&#39;middle&amp;&lt;&gt;&quot;&#39;suffix\"></node>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-034",
            .template = "<node attr='prefix{{ value }}middle{{ value }}suffix'></node>",
            .output = "<node attr='prefix&amp;&lt;&gt;&quot;&#39;middle&amp;&lt;&gt;&quot;&#39;suffix'></node>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-035",
            .template = "before{{ value }}after",
            .output = "before&amp;&lt;&gt;\"'after",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-036",
            .template = "<node attr=\"prefix{{ value }}middle{{ value }}suffix\"></node>",
            .output = "<node attr=\"prefix&amp;&lt;&gt;&quot;&apos;middle&amp;&lt;&gt;&quot;&apos;suffix\"></node>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-037",
            .template = "<node attr='prefix{{ value }}middle{{ value }}suffix'></node>",
            .output = "<node attr='prefix&amp;&lt;&gt;&quot;&apos;middle&amp;&lt;&gt;&quot;&apos;suffix'></node>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-038",
            .template = "{{ '{{' }} missing }}|\\\\{{ value }}|\\q|}}\n",
            .output = "{{ missing }}|\\\\&amp;&lt;&gt;\"'|\\q|}}\n",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-039",
            .template = "<!-- {{ missing }} {% unknown %} \\{{ \\\\ -->",
            .output = "<!-- {{ missing }} {% unknown %} \\{{ \\\\ -->",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-040",
            .template = "<!-- {{ missing }} {% unknown %} \\{{ \\\\ -->",
            .output = "<!-- {{ missing }} {% unknown %} \\{{ \\\\ -->",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-041",
            .template = "<!dOcTyPe\tHtMl \n><p>ok</p>",
            .output = "<!dOcTyPe\tHtMl \n><p>ok</p>",
            .compile_options = .{ .format = .html },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-042",
            .template = "lead<First/><Second />tail",
            .output = "lead<First/><Second />tail",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-043",
            .template = "<_Root.Name a:b='v'><Ns:Child-name /></_Root.Name>",
            .output = "<_Root.Name a:b='v'><Ns:Child-name /></_Root.Name>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-044",
            .template = "<br>child</br><input/>",
            .output = "<br>child</br><input/>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-045",
            .template = "<?xml version='1.0'?><root/>",
            .output = "<?xml version='1.0'?><root/>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-046",
            .template = "<?xml version=\"1.1\" encoding=\"UTF-8\" standalone=\"yes\"?><root />",
            .output = "<?xml version=\"1.1\" encoding=\"UTF-8\" standalone=\"yes\"?><root />",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-047",
            .template = "<?xml version='1.0' encoding='ISO-8859-1' standalone='no'?>",
            .output = "<?xml version='1.0' encoding='ISO-8859-1' standalone='no'?>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-048",
            .template = "&amp;&lt;&gt;&quot;&apos;&#65;&#x41;&#x10FFFF;",
            .output = "&amp;&lt;&gt;&quot;&apos;&#65;&#x41;&#x10FFFF;",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-049",
            .template = "<n a='&amp;&lt;&gt;&quot;&apos;&#65;&#x41;' b=\"&#9;&#10;&#13;\"/>",
            .output = "<n a='&amp;&lt;&gt;&quot;&apos;&#65;&#x41;' b=\"&#9;&#10;&#13;\"/>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-050",
            .template = "<![CDATA[ {{ missing }} {% unknown %} \\{{ & < ]]>after",
            .output = "<![CDATA[ {{ missing }} {% unknown %} \\{{ & < ]]>after",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
    .{
        .fixture = .{
            .id = "MK-051",
            .template = "<![CDATA[first]]><![CDATA[second]]>",
            .output = "<![CDATA[first]]><![CDATA[second]]>",
            .compile_options = .{ .format = .xml },
        },
        .params = .{ .value = "&<>\"'" },
    },
};
