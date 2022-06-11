#!/bin/sh
set -u

get_matrix_send_json() {
  local HTML TXT JHTML JTXT
  readonly HTML="$1"
  readonly TXT="$2"

  readonly JHTML="`printf %s "$HTML" | escape_json`"
  readonly JTXT="`printf %s "$TXT" | escape_json`"
  printf %s \
"{\
\"msgtype\":\"m.text\",\
\"format\":\"org.matrix.custom.html\",\
\"body\":\"$JTXT\",\
\"formatted_body\":\"$JHTML\"\
}"
}

matrix_html_as_text() {
  sed -r "
    s~&lt;br&gt;~\&#xA;~g
    s~&lt;/?(br|li|pre|ul|ol|hr)&gt;~\&#xA;~g
    s~&amp;(quot|amp);~\&\1;~g
    s~&lt;a href=&quot;(([^&]|&[^q])*)&quot; rel=&quot;nofollow noreferrer&quot;&gt;~\1 ~g
    s~ ?&lt;/?[^&]*&gt; ?~ ~g
    s~(&#xA;)+~\&#xA;~g
    s~(&#xA;| )*$~~
    " "$@"
}

unescape() {
  printf "%s" "$1" |
  html_unescape_entities
}

html_unescape_entities() {
  sed -r "
    s~&gt;~>~g
    s~&lt;~<~g
    s~&quot;~\"~g
    s~&#x27;~'~g
    s~&#x2B;~+~g
    s~&amp;~\&~g
    " "$@"
}

escape_json() {
  sed -r "
    s~\\\~&&~g
    s~&#xA;~\\\n~g
    s~\"~\\\&~g
  "
}
