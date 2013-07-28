USING:
    accessors
    arrays
    combinators
    fry
    html.parser html.parser.analyzer
    io
    kernel
    math
    sequences sequences.extras
    sets
    splitting
    unicode.categories
    wrap.strings
    xml xml.entities.html ;
IN: gmane.html2text

TUPLE: state lines indent in-pre? ;

CONSTANT: max-empty-line-count 2

CONSTANT: quote-string " > "

CONSTANT: fill-column 78

: new-line-ok? ( lines -- ? )
    max-empty-line-count dup swapd short tail* [ "" last= ] count > ;

: add-new-line ( lines indent -- lines' )
    over new-line-ok? [ "" ] [ swap unclip-last last swapd ] if 2array suffix ;

: replace-entities ( html-str -- str )
    '[ _ string>xml-chunk ] with-html-entities first ;

: continue-line ( lines str -- lines' )
    [ unclip-last first2 ] dip append 2array suffix ;

: extra-lines ( lines new-lines -- lines' )
    over last first '[ _ swap 2array ] map append ;

: add-lines ( lines new-lines -- lines' )
    unclip swap [ continue-line ] [ extra-lines ] bi* ;

! The rules for what tags causes new lines are somewhat arbitrary and
! choosen based on what makes the rendered emails look the best.
: line-breaking-tags ( -- tagdescs )
    { "pre" "p" "div" "br" "blockquote" } [ f 2array ] map { "p" t } suffix ;

: process-text ( state tag -- state' )
    text>> replace-entities over
    in-pre?>> [ "\n" split ] [ "\n" "" replace 1array ] if
    '[ _ add-lines ] change-lines ;

: process-block ( state tagdesc -- state' )
    {
        [ '[ _ { "blockquote" f } = 1 0 ? + ] change-indent ]
        [
            line-breaking-tags in?
            [ dup indent>> '[ _ add-new-line ] change-lines ] when
        ]
        [ '[ _ { "blockquote" t } = 1 0 ? - ] change-indent ]
        [
            ! Block tags must not end with an empty string.
            { { "div" t } { "blockquote" t } } in?
            [
                [ dup last "" last= [ but-last ] when ] change-lines
            ] when
        ]
        [ first2 swap "pre" = [ not >>in-pre? ] [ drop ] if ]
    } cleave ;

: process-tag ( state tag -- state' )
    dup name>> text =
    [ process-text ] [ [ name>> ] keep closing?>> 2array process-block ] if ;

: fill-columns ( indent -- cols )
    quote-string length * fill-column swap - ;

: split1*-when ( str quot -- before after )
    dupd find drop [ 0 ] unless* cut ; inline

: fill-paragraph ( indent str -- lines )
    dupd [ blank? not ] split1*-when rot fill-columns rot wrap-indented-string
    "\n" split [ 2array ] with map ;

: lines>string ( lines -- str )
    [ first2 fill-paragraph ] map concat
    [ first2 swap [ quote-string ] replicate concat prepend ] map
    ! Merge the lines and ensure the string doesn't start or end with
    ! whitespace.
    "\n" join [ blank? ] trim ;

: tags>string ( tags -- string )
    ! Stray empty text tags are not interesting
    remove-blank-text
    ! Run it through the parsing process
    { } 0 f state boa [ process-tag ] reduce lines>>
    ! Convert the lines to a plain text string
    lines>string ;
