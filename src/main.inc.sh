#!/bin/sh
set +u
if [ -z "$_INCLUDED_MAIN_INC_SH" ]; then
  _INCLUDED_MAIN_INC_SH=1
  . "$(dirname "$(readlink -f "$0")")"/matrix.inc.sh || exit 1
  . "$(dirname "$(readlink -f "$0")")"/utils.inc.sh || exit 1
fi
set -u

main() {
  matrix_init 'main_with_matrix_token' "$@"
}

main_with_matrix_token() {
  local VAR LOCK STATUS

  readonly VAR="$(dirname "$(readlink -f "$0")")/var"
  mkdir -p "$VAR" || return 1

  readonly LOCK="`get_lock_path "$VAR" 'rss-matrix.sh.lock'`"
  if
    mkdir "$LOCK" 2>/dev/null
  then
    process_rss "$VAR/so-bash.atom" 'https://stackoverflow.com/feeds/tag/bash'
    readonly STATUS=$?
    rmdir "$LOCK"
    return $STATUS
  else
    echo "error: lock $LOCK exists" >&2
    return 1
  fi
}

process_rss() {
  local PROCFILE PROCURL STATE TMP
  readonly PROCFILE="$1"
  readonly PROCURL="$2"
  readonly STATE="$VAR/so-cache.csv"
  readonly TMP="$VAR/so.tmp.csv"

  if
    get_rss "$PROCFILE" "$PROCURL"
  then
    {
      cat "$STATE" 2>/dev/null

      rss2csv "$PROCFILE" |
      rss_html2matrix_format
    } |
    sort -u
  else
    cat "$STATE" 2>/dev/null
  fi |
  feed_highly_rated_new_posts "$VAR/posted.csv" > "$TMP"

  mv "$TMP" "$STATE"
}

get_rss() {
  local GETFILE GETURL NOW LAST LASTTIME
  readonly GETFILE="$1"
  readonly GETURL="$2"
  readonly NOW="`date +%s`"
  readonly LAST="$GETFILE.last"
  readonly LASTTIME="`get_file_time "$LAST"`"
  [ $((NOW-LASTTIME)) -ge 3200 ] || return 1

  curl -A 'rss-matrix.sh/0.1' -o "$GETFILE" "$GETURL" || return 1

  if
    cmp -s "$LAST" "$GETFILE"
  then
    touch -r "$GETFILE" "$LAST"
  else
    cp -a "$GETFILE" "$LAST"
  fi
}

rss2csv() {
  sed -r 's/\r+//g' "$@" |
  concat_entry_lines |
  join_categories |
  fields2csv
}

concat_entry_lines() {
  sed -rn '
    s~ *<entry>~~
    T e
    :l
    N
    s~\n *</entry>~~
    t p
    s~\n *~~
    t l
    :p
    p
    :e
    ' "$@"
}

join_categories() {
  sed -r '
    s~<category [^<>]*>~<c>&</c>~g
    s~</c><c>~~g
    s~<category [^<>]* term="([^"]+)" />~\1;~g
    s~;(</c>)~\1~
    ' "$@"
}

fields2csv() {
  sed -rn "
    s~\
.*<re:rank [^>]*>([^<]*)</re:rank>\
.*<title [^>]*>([^<]*)</title>\
.*<c>([^<]*)</c>\
.*<name>([^<]*)</name>\
.*<link [^>]* href=\"([^\"]*)\" />\
.*<published>([^<]*)</published>\
.*<updated>([^<]*)</updated>\
.*<summary type=\"html\">([^<]*)</summary>\
~\1\t\2\t\3\t\4\t\5\t\6\t\7\t\8~
    T e
    p
    :e
    " "$@"
}

rss_html2matrix_format() {
  sed -r '
    s~&lt;img src=&quot;(([^&]|&[^q])*)&quot; alt=&quot;(([^&]|&[^q])*)&quot; /\&gt;~\&lt;a href=\&quot;\1\&quot; rel=\&quot;nofollow noreferrer\&quot;\&gt;img: \3\&lt;/a\&gt;~g
    s~(&#xA;|&lt;br&gt;| )*$~~
    ' "$@"
}

feed_highly_rated_new_posts() {
  local POSTED NOW MXROOM ID R T C N L P U U2 H USEC AGE
  readonly POSTED="$1"

  readonly NOW="`date +%s`"
  readonly MXROOM='!GuHtUfSigQysSwynqq:matrix.org' # #funshell-rss:matrix.org
  
  while IFS="`printf "\t"`" read -r R T C N L P U H; do
    ID="`printf %s "$L" | md5sum | cut -d ' ' -f 1`"
    fgrep -q "$ID" "$POSTED" 2>/dev/null && continue

    # fixup for Busybox ASH
    U2="`printf %s "$U" | sed 's~Z$~~ ; s~T~ ~g'`"
    USEC="$(date -u -d "$U2" +%s)"
    [ -n "$USEC" ] || continue
    AGE="$(((NOW-USEC)/24/3600))"
    if [ "$R" -ge 3 ] && [ "$AGE" -gt 2 ] || [ "$R" -ge 6 ]; then
      matrix_send_json "$MXROOM" "`csv2json`" >&2 &&

      printf "%s\n" "$ID" >> "$POSTED"
    elif [ "$AGE" -le 2 ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$R" "$T" "$C" "$N" "$L" "$P" "$U" "$H"
    fi
  done
}

csv2json() {
  local BODYTXT UT UC UN UL UH MSGTXT MSGHTML
  readonly UT="`unescape "$T"`"
  readonly UC="`unescape "$C"`"
  readonly UN="`unescape "$N"`"
  readonly UL="`unescape "$L"`"
  readonly UH="`unescape "$H"`"
  readonly BODYTXT="`printf %s "$H" | matrix_html_as_text | html_unescape_entities`"
  readonly MSGTXT="$UT: $BODYTXT - asked by $UN, updated $U, rank $R, category $UC, see $UL"
  readonly MSGHTML="<a href=\"$L\"><h4>$T</h4></a><p>asked by <code>$N</code> on $P, rank $R, category <em>$C</em></p><blockquote>$UH</blockquote>"
  get_matrix_send_json "$MSGHTML" "$MSGTXT"
}
