#!/usr/bin/env python3
import sys
from pathlib import Path


def replace_once(text: str, old: str, new: str) -> str:
    if old not in text:
        raise SystemExit(f"pattern not found: {old!r}")
    return text.replace(old, new, 1)


path = Path(sys.argv[1])
text = path.read_text()

if "'plugin_mode'" not in text:
    text = replace_once(
        text,
        "\t'plugin_opts',\n];",
        "\t'plugin_opts',\n\t'plugin_mode',\n];",
    )

if "form.ListValue, 'plugin_mode'" not in text:
    text = replace_once(
        text,
        "\t\toptfunc(form.Value, 'plugin_opts', _('Plugin Options')).modalonly = true;\n\t},",
        "\t\toptfunc(form.Value, 'plugin_opts', _('Plugin Options')).modalonly = true;\n\n"
        "\t\to = optfunc(form.ListValue, 'plugin_mode', _('Plugin mode'));\n"
        "\t\to.value('', _('<unset>'));\n"
        "\t\tmodes.forEach(function(m) {\n"
        "\t\t\to.value(m);\n"
        "\t\t});\n"
        "\t\to.default = '';\n"
        "\t\to.rmempty = true;\n"
        "\t\to.modalonly = true;\n"
        "\t},",
    )

path.write_text(text)
