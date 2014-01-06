USING:
    accessors
    arrays
    assocs
    calendar calendar.format
    combinators
    continuations
    formatting
    fry
    imap
    io.streams.duplex
    kernel
    math math.parser math.ranges math.statistics
    namespaces
    pcre
    random
    sequences
    sets
    strings
    tools.test ;
IN: imap.tests

! Set these to your email account.
SYMBOLS: email host password ;

: random-ascii ( n -- str )
    [ CHAR: a CHAR: z [a,b] random ] "" replicate-as ;

: make-mail ( from -- mail )
    now timestamp>rfc822 swap 10000 random
    3array {
        "Date: %s"
        "From: %s"
        "Subject: afternoon meeting"
        "To: mooch@owatagu.siam.edu"
        "Message-Id: <%08d@Blurdybloop.COM>"
        "MIME-Version: 1.0"
        "Content-Type: TEXT/PLAIN; CHARSET=US-ASCII"
        ""
        "Hello Joe, do you think we can meet at 3:30 tomorrow?"
    } "\r\n" join vsprintf ;

: sample-mail ( -- mail )
    "Fred Foobar <foobar@Blurdybloop.COM>" make-mail ;

! Fails unless you have set the settings.
: imap-login ( -- imap4 )
    host get <imap4ssl> dup [ email get password get login drop ] with-stream* ;

[ t ] [
    host get <imap4ssl> duplex-stream?
] unit-test

[ t ] [
    host get <imap4ssl> [ capabilities ] with-stream
    { "IMAP4rev1" "UNSELECT" "IDLE" "NAMESPACE" "QUOTA" } swap subset?
] unit-test

[ "NO" ] [
    [ host get <imap4ssl> [ "dont@exist.com" "foo" login ] with-stream ]
    [ ind>> ] recover
] unit-test

[ "BAD" ] [
    [ host get <imap4ssl> [ f f login ] with-stream ] [ ind>> ] recover
] unit-test

[ f ] [
    host get <imap4ssl> [
        email get password get login
    ] with-stream empty?
] unit-test

! Newly created and then selected folder is empty.
[ 0 { } ] [
    imap-login [
        10 random-ascii
        [ create-folder ]
        [ select-folder ]
        [ delete-folder ] tri
        "ALL" "" search-mails
    ] with-stream
] unit-test

! Create delete select again.
[ 0 ] [
    imap-login [
        "örjan" [ create-folder ] [ select-folder ] [ delete-folder ] tri
    ] with-stream
] unit-test

! Test list folders
[ t ] [
    imap-login [
        10 random-ascii
        [ create-folder "*" list-folders length 0 > ] [ delete-folder ] bi
    ] with-stream
] unit-test

! Generate some mails for searching
[ t t f f ] [
    imap-login [
        10 random-ascii
        {
            [ create-folder ]
            [
                '[ _ "(\\Seen)" now sample-mail append-mail drop ]
                10 swap times
            ]
            [
                select-folder drop
                "ALL" "" search-mails
                5 sample "(RFC822)" fetch-mails
                [ [ string? ] all? ] [ length 5 = ] bi
                "SUBJECT" "afternoon" search-mails empty?
                "(SINCE \"01-Jan-2014\")" "" search-mails empty?
            ]
            [ delete-folder ]
        } cleave
    ] with-stream
] unit-test

! Stat folder
[ t ] [
    imap-login [
        10 random-ascii
        {
            [ create-folder ]
            [
                '[ _ "(\\Seen)" now sample-mail append-mail drop ]
                10 swap times
            ]
            [
                { "MESSAGES" "UNSEEN" } status-folder
                [ "MESSAGES" of 0 > ] [ "UNSEEN" of 0 >= ] bi and
            ]
            [ delete-folder ]
        } cleave
    ] with-stream
] unit-test

! Rename folder
[ ] [
    imap-login [
        "日本語" [ create-folder ] [
            "ascii-name" [ rename-folder ] [ delete-folder ] bi
        ] bi
    ] with-stream
] unit-test

! Create a folder hierarchy
[ t ] [
    imap-login [
        "*" list-folders length
        "foo/bar/baz/日本語" [
            create-folder "*" list-folders length 4 - =
        ] [ delete-folder ] bi
    ]  with-stream
] unit-test

! A gmail compliant way of creating a folder hierarchy.
[ ] [
    imap-login [
        "foo/bar/baz/boo" "/" split { } [ suffix ] cum-map [ "/" join ] map
        [ [ create-folder ] each ] [ [ delete-folder ] each ] bi
    ] with-stream
] unit-test

[ ] [
    imap-login [
        "örjan" {
            [ create-folder ]
            [ select-folder drop ]
            ! Append mail with a seen flag
            [ "(\\Seen)" now sample-mail append-mail drop ]
            ! And one without
            [ "" now sample-mail append-mail drop ]
            [ delete-folder ]
        } cleave
    ] with-stream
] unit-test

! Exercise store-mail
[ t ] [
    imap-login [
        "INBOX" select-folder drop "ALL" "" search-mails
        5 sample "+FLAGS" "(\\Recent)" store-mail
    ] with-stream length 5 =
] unit-test
