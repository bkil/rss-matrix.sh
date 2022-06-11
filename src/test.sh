#!/bin/sh

. "$(dirname "$(readlink -f "$0")")"/main.inc.sh || exit 1

test_csv2json() {
  R=42
  T='Title &amp; newline=\n &quot;test&quot;'
  C='now&amp;then'
  N='&quot;name&quot; &amp; co'
  L='https://localhost/?x&amp;y'
  P='2022'
  U='2022'
  H='a&lt;br&gt;b&lt;pre&gt;&#xA;printf &quot;hi\n&quot;&amp;amp;&lt;/pre&gt;'
  csv2json
}

test_csv2json
