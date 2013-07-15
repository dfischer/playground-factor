USING:
    accessors
    assocs
    combinators
    db db.sqlite db.tuples db.types
    formatting
    fry
    gmane.db
    io
    kernel
    math.parser
    mirrors
    sequences
    sets
    splitting
    unicode.case unicode.categories ;
IN: gmane.fts

TUPLE: word id str ;

word "word" {
  { "id" "id" +db-assigned-id+ }
  { "str" "str" TEXT }
} define-persistent

TUPLE: word-to-mail word-id mail-id ;

word-to-mail "word_to_mail" {
  { "word-id" "word_id" INTEGER }
  { "mail-id" "mail_id" INTEGER }
} define-persistent

TUPLE: indexed-mail mail-id ;

indexed-mail "indexed_mail" {
  { "mail-id" "mail_id" INTEGER }
} define-persistent

: <word> ( str -- word )
  f swap word boa ;

: <indexed-mail> ( id -- indexed-mail )
  indexed-mail boa ;

: db-init ( -- )
  [ { word word-to-mail indexed-mail } ensure-tables ] with-mydb ;

: db-insert ( tup -- id )
  insert-tuple last-insert-id ;

: db-ensure ( tup -- id )
  dup select-tuple [ id>> nip ] [ db-insert ] if* ;

: db-ensure* ( tup -- )
  dup select-tuple [ db-insert ] unless drop ;

: db-row-by-id ( id tup-type -- row )
  new swap >>id select-tuple ;

: get-search-string ( mail -- str )
  <mirror> '[ _ at ] { "body" "group" "sender" "subject" } swap map " " join ;

: string>tokens ( str -- seq )
  >lower [ letter? not ] split-when [ empty? not ] filter members ;

: get-mail-tokens ( id -- seq )
  mail db-row-by-id get-search-string string>tokens ;

: str>word-id ( str -- word-id )
  <word> db-ensure ;

: get-mail-words ( id -- words )
  get-mail-tokens [ str>word-id ] map ;

: index-mail ( id -- seq )
  dup get-mail-words swap '[ _ word-to-mail boa dup db-ensure* ] map ;

: ensure-mail-indexed ( id -- seq )
  [ index-mail ] [ <indexed-mail> db-ensure* ] bi ;

: missing-mails ( -- seq )
  {
    "select m.id"
    "from mail m left join indexed_mail im on im.mail_id = m.id"
    "where im.mail_id is null"
  } " " join sql-query [ first string>number ] map ;

: update ( -- )
  [
    missing-mails
    [
      [ subject>> "Indexing mail '%s' ... " printf flush ]
      [ id>> ensure-mail-indexed length " %s new words\n" printf flush ] bi
    ] each
  ] with-mydb ;