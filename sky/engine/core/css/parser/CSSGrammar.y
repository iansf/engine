%{

/*
 *  Copyright (C) 2002-2003 Lars Knoll (knoll@kde.org)
 *  Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013 Apple Inc. All rights reserved.
 *  Copyright (C) 2006 Alexey Proskuryakov (ap@nypop.com)
 *  Copyright (C) 2008 Eric Seidel <eric@webkit.org>
 *  Copyright (C) 2012 Intel Corporation. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#include "CSSPropertyNames.h"
#include "core/css/CSSPrimitiveValue.h"
#include "core/css/CSSSelector.h"
#include "core/css/CSSSelectorList.h"
#include "core/css/StyleRule.h"
#include "core/css/StyleSheetContents.h"
#include "core/css/parser/BisonCSSParser.h"
#include "core/css/parser/CSSParserMode.h"
#include "core/dom/Document.h"
#include "wtf/FastMalloc.h"
#include <stdlib.h>
#include <string.h>

using namespace blink;

#define YYMALLOC fastMalloc
#define YYFREE fastFree

#define YYENABLE_NLS 0
#define YYLTYPE_IS_TRIVIAL 1
#define YYMAXDEPTH 10000
#define YYDEBUG 0

#if YYDEBUG > 0
#define YYPRINT(File,Type,Value) if (isCSSTokenAString(Type)) YYFPRINTF(File, "%s", String((Value).string).utf8().data())
#endif

%}

%pure-parser

%parse-param { BisonCSSParser* parser }
%lex-param { BisonCSSParser* parser }

%union {
    bool boolean;
    char character;
    int integer;
    double number;
    CSSParserString string;

    StyleRuleBase* rule;
    // The content of the three below HeapVectors are guaranteed to be kept alive by
    // the corresponding m_parsedRules.
    // lists in BisonCSSParser.h.
    Vector<RefPtr<StyleRuleBase> >* ruleList;
    CSSParserSelector* selector;
    Vector<OwnPtr<CSSParserSelector> >* selectorList;
    CSSSelector::AttributeMatchType attributeMatchType;
    CSSParserValue value;
    CSSParserValueList* valueList;
    float val;
    CSSPropertyID id;
    CSSParserLocation location;
}

%{

static inline int cssyyerror(void*, const char*)
{
    return 1;
}

#if YYDEBUG > 0
static inline bool isCSSTokenAString(int yytype)
{
    switch (yytype) {
    case IDENT:
    case STRING:
    case NTH:
    case HEX:
    case IDSEL:
    case DIMEN:
    case INVALIDDIMEN:
    case URI:
    case FUNCTION:
    case HOSTFUNCTION:
    case NOTFUNCTION:
    case CALCFUNCTION:
    case UNICODERANGE:
        return true;
    default:
        return false;
    }
}
#endif

inline static CSSParserValue makeOperatorValue(int value)
{
    CSSParserValue v;
    v.id = CSSValueInvalid;
    v.isInt = false;
    v.unit = CSSParserValue::Operator;
    v.iValue = value;
    return v;
}

inline static CSSParserValue makeIdentValue(CSSParserString string)
{
    CSSParserValue v;
    v.id = cssValueKeywordID(string);
    v.isInt = false;
    v.unit = CSSPrimitiveValue::CSS_IDENT;
    v.string = string;
    return v;
}

%}

%expect 0

%nonassoc LOWEST_PREC

%left UNIMPORTANT_TOK

%token WHITESPACE SGML_CD
%token TOKEN_EOF 0

%token <string> STRING
%right <string> IDENT
%token <string> NTH

%nonassoc <string> HEX
%nonassoc <string> IDSEL
%nonassoc ':'
%nonassoc '.'
%nonassoc '['
%nonassoc <string> '*'
%nonassoc error
%left '|'

%token SUPPORTS_SYM
%token FONT_FACE_SYM
%token CHARSET_SYM
%token INTERNAL_DECLS_SYM
%token INTERNAL_RULE_SYM
%token INTERNAL_SELECTOR_SYM
%token INTERNAL_VALUE_SYM
%token INTERNAL_SUPPORTS_CONDITION_SYM

%token ATKEYWORD

%token SUPPORTS_NOT
%token SUPPORTS_AND
%token SUPPORTS_OR

%token <number> CHS
%token <number> EMS
%token <number> EXS
%token <number> PXS
%token <number> CMS
%token <number> MMS
%token <number> INS
%token <number> PTS
%token <number> PCS
%token <number> DEGS
%token <number> RADS
%token <number> GRADS
%token <number> TURNS
%token <number> MSECS
%token <number> SECS
%token <number> HERTZ
%token <number> KHERTZ
%token <string> DIMEN
%token <string> INVALIDDIMEN
%token <number> PERCENTAGE
%token <number> FLOATTOKEN
%token <number> INTEGER
%token <number> VW
%token <number> VH
%token <number> VMIN
%token <number> VMAX
%token <number> DPPX
%token <number> DPI
%token <number> DPCM
%token <number> FR

%token <string> URI
%token <string> FUNCTION
%token <string> NOTFUNCTION
%token <string> CALCFUNCTION
%token <string> HOSTFUNCTION

%token <string> UNICODERANGE

%type <rule> ruleset
%type <rule> font_face
%type <rule> rule
%type <rule> valid_rule
%type <ruleList> block_rule_body
%type <ruleList> block_rule_list
%type <rule> block_rule
%type <rule> block_valid_rule
%type <rule> supports

%type <string> ident_or_string

%type <boolean> supports_condition
%type <boolean> supports_condition_in_parens
%type <boolean> supports_negation
%type <boolean> supports_conjunction
%type <boolean> supports_disjunction
%type <boolean> supports_declaration_condition

%type <id> property

%type <selector> specifier
%type <selector> specifier_list
%type <selector> simple_selector
%type <selector> selector
%type <selectorList> selector_list
%type <selectorList> simple_selector_list
%type <selector> class
%type <selector> attrib
%type <selector> pseudo

%type <boolean> declaration_list
%type <boolean> decl_list
%type <boolean> declaration

%type <integer> unary_operator
%type <integer> maybe_unary_operator
%type <character> operator

%type <valueList> expr
%type <value> term
%type <value> unary_term
%type <value> function
%type <value> calc_func_term
%type <character> calc_func_operator
%type <valueList> calc_func_expr
%type <valueList> calc_func_paren_expr
%type <value> calc_function

%type <string> element_name
%type <string> attr_name

%type <attributeMatchType> attr_match_type
%type <attributeMatchType> maybe_attr_match_type

%type <location> error_location

%type <valueList> ident_list
%type <value> track_names_list

%%

stylesheet:
    maybe_charset maybe_sgml rule_list
  | internal_decls
  | internal_rule
  | internal_selector
  | internal_value
  | internal_supports_condition
  ;

internal_rule:
    INTERNAL_RULE_SYM maybe_space valid_rule maybe_space TOKEN_EOF {
        parser->m_rule = $3;
    }
;

internal_decls:
    INTERNAL_DECLS_SYM maybe_space_before_declaration declaration_list TOKEN_EOF {
        /* can be empty */
    }
;

internal_value:
    INTERNAL_VALUE_SYM maybe_space expr TOKEN_EOF {
        parser->m_valueList = parser->sinkFloatingValueList($3);
        int oldParsedProperties = parser->m_parsedProperties.size();
        if (!parser->parseValue(parser->m_id))
            parser->rollbackLastProperties(parser->m_parsedProperties.size() - oldParsedProperties);
        parser->m_valueList = nullptr;
    }
;

internal_selector:
    INTERNAL_SELECTOR_SYM maybe_space selector_list TOKEN_EOF {
        if (parser->m_selectorListForParseSelector)
            parser->m_selectorListForParseSelector->adoptSelectorVector(*$3);
    }
;

internal_supports_condition:
    INTERNAL_SUPPORTS_CONDITION_SYM maybe_space supports_condition TOKEN_EOF {
        parser->m_supportsCondition = $3;
    }
;

space:
    WHITESPACE
  | space WHITESPACE
  ;

maybe_space:
    /* empty */ %prec UNIMPORTANT_TOK
  | space
  ;

maybe_sgml:
    /* empty */
  | maybe_sgml SGML_CD
  | maybe_sgml WHITESPACE
  ;

closing_brace:
    '}'
  | %prec LOWEST_PREC TOKEN_EOF
  ;

closing_parenthesis:
    ')'
  | %prec LOWEST_PREC TOKEN_EOF
  ;

closing_square_bracket:
    ']'
  | %prec LOWEST_PREC TOKEN_EOF
  ;

semi_or_eof:
    ';'
  | TOKEN_EOF
  ;

maybe_charset:
    /* empty */
  | CHARSET_SYM maybe_space STRING maybe_space semi_or_eof {
       // FIXME(sky): Remove all support for @charset.
       parser->startEndUnknownRule();
    }
  | CHARSET_SYM at_rule_recovery
  ;

rule_list:
   /* empty */
 | rule_list rule maybe_sgml {
     if ($2 && parser->m_styleSheet)
         parser->m_styleSheet->parserAppendRule($2);
 }
 ;

valid_rule:
    ruleset
  | font_face
  | supports
  ;

before_rule:
    /* empty */ {
        parser->startRule();
    }
  ;

rule:
    before_rule valid_rule {
        $$ = $2;
        parser->m_hadSyntacticallyValidCSSRule = true;
        parser->endRule(!!$$);
    }
  | before_rule invalid_rule {
        $$ = 0;
        parser->endRule(false);
    }
  ;

block_rule_body:
    block_rule_list
  | block_rule_list block_rule_recovery
    ;

block_rule_list:
    /* empty */ { $$ = 0; }
  | block_rule_list block_rule maybe_sgml {
      $$ = parser->appendRule($1, $2);
    }
    ;

block_rule_recovery:
    before_rule invalid_rule_header {
        parser->endRule(false);
    }
  ;

block_valid_rule:
    ruleset
  | font_face
  | supports
  ;

block_rule:
    before_rule block_valid_rule {
        $$ = $2;
        parser->endRule(!!$$);
    }
  | before_rule invalid_rule {
        $$ = 0;
        parser->endRule(false);
    }
  ;

at_rule_body_start:
    /* empty */ {
        parser->startRuleBody();
    }
    ;

at_rule_header_end_maybe_space:
    maybe_space {
        parser->endRuleHeader();
    }
    ;

supports:
    before_supports_rule SUPPORTS_SYM maybe_space supports_condition at_supports_rule_header_end '{' at_rule_body_start maybe_space block_rule_body closing_brace {
        $$ = parser->createSupportsRule($4, $9);
    }
    ;

before_supports_rule:
    /* empty */ {
        parser->startRuleHeader(CSSRuleSourceData::SUPPORTS_RULE);
        parser->markSupportsRuleHeaderStart();
    }
    ;

at_supports_rule_header_end:
    /* empty */ {
        parser->endRuleHeader();
        parser->markSupportsRuleHeaderEnd();
    }
    ;

supports_condition:
    supports_condition_in_parens
    | supports_negation
    | supports_conjunction
    | supports_disjunction
    ;

supports_negation:
    SUPPORTS_NOT maybe_space supports_condition_in_parens {
        $$ = !$3;
    }
    ;

supports_conjunction:
    supports_condition_in_parens SUPPORTS_AND maybe_space supports_condition_in_parens {
        $$ = $1 && $4;
    }
    | supports_conjunction SUPPORTS_AND maybe_space supports_condition_in_parens {
        $$ = $1 && $4;
    }
    ;

supports_disjunction:
    supports_condition_in_parens SUPPORTS_OR maybe_space supports_condition_in_parens {
        $$ = $1 || $4;
    }
    | supports_disjunction SUPPORTS_OR maybe_space supports_condition_in_parens {
        $$ = $1 || $4;
    }
    ;

supports_condition_in_parens:
    '(' maybe_space supports_condition closing_parenthesis maybe_space {
        $$ = $3;
    }
    | supports_declaration_condition
    | '(' error error_location error_recovery closing_parenthesis maybe_space {
        parser->reportError($3, InvalidSupportsConditionCSSError);
        $$ = false;
    }
    ;

supports_declaration_condition:
    '(' maybe_space IDENT maybe_space ':' maybe_space expr closing_parenthesis maybe_space {
        $$ = false;
        CSSPropertyID id = cssPropertyID($3);
        if (id != CSSPropertyInvalid) {
            parser->m_valueList = parser->sinkFloatingValueList($7);
            int oldParsedProperties = parser->m_parsedProperties.size();
            $$ = parser->parseValue(id);
            // We just need to know if the declaration is supported as it is written. Rollback any additions.
            if ($$)
                parser->rollbackLastProperties(parser->m_parsedProperties.size() - oldParsedProperties);
        }
        parser->m_valueList = nullptr;
        parser->endProperty(false);
    }
    | '(' maybe_space IDENT maybe_space ':' maybe_space error error_recovery closing_parenthesis maybe_space {
        $$ = false;
        parser->endProperty(false, GeneralCSSError);
    }
    ;

before_font_face_rule:
    /* empty */ {
        parser->startRuleHeader(CSSRuleSourceData::FONT_FACE_RULE);
    }
    ;

font_face:
    before_font_face_rule FONT_FACE_SYM at_rule_header_end_maybe_space
    '{' at_rule_body_start maybe_space_before_declaration declaration_list closing_brace {
        $$ = parser->createFontFaceRule();
    }
    ;

maybe_unary_operator:
    unary_operator
    | /* empty */ { $$ = 1; }
    ;

unary_operator:
    '-' { $$ = -1; }
  | '+' { $$ = 1; }
  ;

maybe_space_before_declaration:
    maybe_space {
        parser->startProperty();
    }
  ;

before_selector_list:
    /* empty */ {
        parser->startRuleHeader(CSSRuleSourceData::STYLE_RULE);
        parser->startSelector();
    }
  ;

at_rule_header_end:
    /* empty */ {
        parser->endRuleHeader();
    }
  ;

at_selector_end:
    /* empty */ {
        parser->endSelector();
    }
  ;

ruleset:
    before_selector_list selector_list at_selector_end at_rule_header_end '{' at_rule_body_start maybe_space_before_declaration declaration_list closing_brace {
        $$ = parser->createStyleRule($2);
    }
  ;

before_selector_group_item:
    /* empty */ {
        parser->startSelector();
    }

selector_list:
    selector %prec UNIMPORTANT_TOK {
        $$ = parser->reusableSelectorVector();
        $$->shrink(0);
        $$->append(parser->sinkFloatingSelector($1));
    }
    | selector_list at_selector_end ',' maybe_space before_selector_group_item selector %prec UNIMPORTANT_TOK {
        $$ = $1;
        $$->append(parser->sinkFloatingSelector($6));
    }
   ;

selector:
    simple_selector
    | selector WHITESPACE
    ;

simple_selector:
    element_name {
        $$ = parser->createFloatingSelectorWithTagName(QualifiedName($1));
    }
    | element_name specifier_list {
        $$ = parser->rewriteSpecifiersWithElementName(nullAtom, $1, $2);
        if (!$$)
            YYERROR;
    }
    | specifier_list {
        $$ = parser->rewriteSpecifiersWithNamespaceIfNeeded($1);
        if (!$$)
            YYERROR;
    }
  ;

simple_selector_list:
    simple_selector %prec UNIMPORTANT_TOK {
        $$ = parser->createFloatingSelectorVector();
        $$->append(parser->sinkFloatingSelector($1));
    }
    | simple_selector_list maybe_space ',' maybe_space simple_selector %prec UNIMPORTANT_TOK {
        $$ = $1;
        $$->append(parser->sinkFloatingSelector($5));
    }
  ;

element_name:
    IDENT {
        $$ = $1;
    }
    | '*' {
        static const LChar star = '*';
        $$.init(&star, 1);
    }
  ;

specifier_list:
    specifier
    | specifier_list specifier {
        $$ = parser->rewriteSpecifiers($1, $2);
    }
;

specifier:
    IDSEL {
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::Id);
        if (isQuirksModeBehavior(parser->m_context.mode()))
            parser->tokenToLowerCase($1);
        $$->setValue($1);
    }
  | HEX {
        if ($1[0] >= '0' && $1[0] <= '9') {
            YYERROR;
        } else {
            $$ = parser->createFloatingSelector();
            $$->setMatch(CSSSelector::Id);
            if (isQuirksModeBehavior(parser->m_context.mode()))
                parser->tokenToLowerCase($1);
            $$->setValue($1);
        }
    }
  | class
  | attrib
  | pseudo
    ;

class:
    '.' IDENT {
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::Class);
        if (isQuirksModeBehavior(parser->m_context.mode()))
            parser->tokenToLowerCase($2);
        $$->setValue($2);
    }
  ;

attr_name:
    IDENT maybe_space {
        $$ = $1;
    }
    ;

attr_match_type:
    IDENT maybe_space {
        CSSSelector::AttributeMatchType attrMatchType = CSSSelector::CaseSensitive;
        if (!parser->parseAttributeMatchType(attrMatchType, $1))
            YYERROR;
        $$ = attrMatchType;
    }
    ;

maybe_attr_match_type:
    attr_match_type
    | /* empty */ { $$ = CSSSelector::CaseSensitive; }
    ;

attrib:
    '[' maybe_space attr_name closing_square_bracket {
        $$ = parser->createFloatingSelector();
        $$->setAttribute(QualifiedName($3), CSSSelector::CaseSensitive);
        $$->setMatch(CSSSelector::Set);
    }
    | '[' maybe_space attr_name '=' maybe_space ident_or_string maybe_space maybe_attr_match_type closing_square_bracket {
        $$ = parser->createFloatingSelector();
        $$->setAttribute(QualifiedName($3), $8);
        $$->setMatch(CSSSelector::Exact);
        $$->setValue($6);
    }
    | '[' selector_recovery closing_square_bracket {
        YYERROR;
    }
  ;

ident_or_string:
    IDENT
  | STRING
    ;

pseudo:
    ':' error_location IDENT {
        if ($3.isFunction())
            YYERROR;
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::PseudoClass);
        parser->tokenToLowerCase($3);
        $$->setValue($3);
        CSSSelector::PseudoType type = $$->pseudoType();
        if (type == CSSSelector::PseudoUnknown) {
            parser->reportError($2, InvalidSelectorPseudoCSSError);
            YYERROR;
        }
    }
    | ':' ':' error_location IDENT {
        if ($4.isFunction())
            YYERROR;
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::PseudoElement);
        parser->tokenToLowerCase($4);
        $$->setValue($4);
        // FIXME: This call is needed to force selector to compute the pseudoType early enough.
        CSSSelector::PseudoType type = $$->pseudoType();
        if (type == CSSSelector::PseudoUnknown) {
            parser->reportError($3, InvalidSelectorPseudoCSSError);
            YYERROR;
        }
    }
    // used by :nth-*(ax+b)
    | ':' FUNCTION maybe_space NTH maybe_space closing_parenthesis {
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::PseudoClass);
        $$->setArgument($4);
        $$->setValue($2);
        CSSSelector::PseudoType type = $$->pseudoType();
        if (type == CSSSelector::PseudoUnknown)
            YYERROR;
    }
    // used by :nth-*
    | ':' FUNCTION maybe_space maybe_unary_operator INTEGER maybe_space closing_parenthesis {
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::PseudoClass);
        $$->setArgument(AtomicString::number($4 * $5));
        $$->setValue($2);
        CSSSelector::PseudoType type = $$->pseudoType();
        if (type == CSSSelector::PseudoUnknown)
            YYERROR;
    }
    // used by :nth-*(odd/even) and :lang
    | ':' FUNCTION maybe_space IDENT maybe_space closing_parenthesis {
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::PseudoClass);
        $$->setArgument($4);
        parser->tokenToLowerCase($2);
        $$->setValue($2);
        CSSSelector::PseudoType type = $$->pseudoType();
        if (type == CSSSelector::PseudoUnknown)
            YYERROR;
    }
    | ':' FUNCTION selector_recovery closing_parenthesis {
        YYERROR;
    }
    // used by :not
    | ':' NOTFUNCTION maybe_space simple_selector maybe_space closing_parenthesis {
        if (!$4->isSimple())
            YYERROR;
        else {
            $$ = parser->createFloatingSelector();
            $$->setMatch(CSSSelector::PseudoClass);

            Vector<OwnPtr<CSSParserSelector> > selectorVector;
            selectorVector.append(parser->sinkFloatingSelector($4));
            $$->adoptSelectorVector(selectorVector);

            parser->tokenToLowerCase($2);
            $$->setValue($2);
        }
    }
    | ':' NOTFUNCTION selector_recovery closing_parenthesis {
        YYERROR;
    }
    | ':' HOSTFUNCTION maybe_space simple_selector_list maybe_space closing_parenthesis {
        $$ = parser->createFloatingSelector();
        $$->setMatch(CSSSelector::PseudoClass);
        $$->adoptSelectorVector(*parser->sinkFloatingSelectorVector($4));
        parser->tokenToLowerCase($2);
        $$->setValue($2);
        CSSSelector::PseudoType type = $$->pseudoType();
        if (type != CSSSelector::PseudoHost)
            YYERROR;
    }
    | ':' HOSTFUNCTION selector_recovery closing_parenthesis {
        YYERROR;
    }
  ;

selector_recovery:
    error error_location error_recovery;

declaration_list:
    /* empty */ { $$ = false; }
    | declaration
    | decl_list declaration {
        $$ = $1 || $2;
    }
    | decl_list
    ;

decl_list:
    declaration ';' maybe_space {
        parser->startProperty();
        $$ = $1;
    }
    | decl_list declaration ';' maybe_space {
        parser->startProperty();
        $$ = $1 || $2;
    }
    ;

declaration:
    property ':' maybe_space error_location expr {
        $$ = false;
        bool isPropertyParsed = false;
        if ($1 != CSSPropertyInvalid) {
            parser->m_valueList = parser->sinkFloatingValueList($5);
            int oldParsedProperties = parser->m_parsedProperties.size();
            $$ = parser->parseValue($1);
            if (!$$) {
                parser->rollbackLastProperties(parser->m_parsedProperties.size() - oldParsedProperties);
                parser->reportError($4, InvalidPropertyValueCSSError);
            } else
                isPropertyParsed = true;
            parser->m_valueList = nullptr;
        }
        parser->endProperty(isPropertyParsed);
    }
    |
    property ':' maybe_space error_location expr error error_recovery {
        /* When we encounter something like p {color: red !important fail;} we should drop the declaration */
        parser->reportError($4, InvalidPropertyValueCSSError);
        parser->endProperty(false);
        $$ = false;
    }
    |
    property ':' maybe_space error_location error error_recovery {
        parser->reportError($4, InvalidPropertyValueCSSError);
        parser->endProperty(false);
        $$ = false;
    }
    |
    property error error_location error_recovery {
        parser->reportError($3, PropertyDeclarationCSSError);
        parser->endProperty(false, GeneralCSSError);
        $$ = false;
    }
    |
    error error_location error_recovery {
        parser->reportError($2, PropertyDeclarationCSSError);
        $$ = false;
    }
  ;

property:
    error_location IDENT maybe_space {
        $$ = cssPropertyID($2);
        parser->setCurrentProperty($$);
        if ($$ == CSSPropertyInvalid)
            parser->reportError($1, InvalidPropertyCSSError);
    }
  ;

ident_list:
    IDENT maybe_space {
        $$ = parser->createFloatingValueList();
        $$->addValue(makeIdentValue($1));
    }
    | ident_list IDENT maybe_space {
        $$ = $1;
        $$->addValue(makeIdentValue($2));
    }
    ;

track_names_list:
    '(' maybe_space closing_parenthesis {
        $$.setFromValueList(parser->sinkFloatingValueList(parser->createFloatingValueList()));
    }
    | '(' maybe_space ident_list closing_parenthesis {
        $$.setFromValueList(parser->sinkFloatingValueList($3));
    }
    | '(' maybe_space expr_recovery closing_parenthesis {
        YYERROR;
    }
  ;

expr:
    term {
        $$ = parser->createFloatingValueList();
        $$->addValue(parser->sinkFloatingValue($1));
    }
    | expr operator term {
        $$ = $1;
        $$->addValue(makeOperatorValue($2));
        $$->addValue(parser->sinkFloatingValue($3));
    }
    | expr term {
        $$ = $1;
        $$->addValue(parser->sinkFloatingValue($2));
    }
  ;

expr_recovery:
    error error_location error_recovery {
        parser->reportError($2, PropertyDeclarationCSSError);
    }
  ;

operator:
    '/' maybe_space {
        $$ = '/';
    }
  | ',' maybe_space {
        $$ = ',';
    }
  ;

term:
  unary_term maybe_space
  | unary_operator unary_term maybe_space { $$ = $2; $$.fValue *= $1; }
  | STRING maybe_space { $$.id = CSSValueInvalid; $$.isInt = false; $$.string = $1; $$.unit = CSSPrimitiveValue::CSS_STRING; }
  | IDENT maybe_space { $$ = makeIdentValue($1); }
  /* We might need to actually parse the number from a dimension, but we can't just put something that uses $$.string into unary_term. */
  | DIMEN maybe_space { $$.id = CSSValueInvalid; $$.string = $1; $$.isInt = false; $$.unit = CSSPrimitiveValue::CSS_DIMENSION; }
  | unary_operator DIMEN maybe_space { $$.id = CSSValueInvalid; $$.string = $2; $$.isInt = false; $$.unit = CSSPrimitiveValue::CSS_DIMENSION; }
  | URI maybe_space { $$.id = CSSValueInvalid; $$.string = $1; $$.isInt = false; $$.unit = CSSPrimitiveValue::CSS_URI; }
  | UNICODERANGE maybe_space { $$.id = CSSValueInvalid; $$.string = $1; $$.isInt = false; $$.unit = CSSPrimitiveValue::CSS_UNICODE_RANGE; }
  | HEX maybe_space { $$.id = CSSValueInvalid; $$.string = $1; $$.isInt = false; $$.unit = CSSPrimitiveValue::CSS_PARSER_HEXCOLOR; }
  | '#' maybe_space { $$.id = CSSValueInvalid; $$.string = CSSParserString(); $$.isInt = false; $$.unit = CSSPrimitiveValue::CSS_PARSER_HEXCOLOR; } /* Handle error case: "color: #;" */
  /* FIXME: according to the specs a function can have a unary_operator in front. I know no case where this makes sense */
  | function maybe_space
  | calc_function maybe_space
  | '%' maybe_space { /* Handle width: %; */
      $$.id = CSSValueInvalid; $$.isInt = false; $$.unit = 0;
  }
  | track_names_list maybe_space
  ;

unary_term:
  INTEGER { $$.setFromNumber($1); $$.isInt = true; }
  | FLOATTOKEN { $$.setFromNumber($1); }
  | PERCENTAGE { $$.setFromNumber($1, CSSPrimitiveValue::CSS_PERCENTAGE); }
  | PXS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_PX); }
  | CMS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_CM); }
  | MMS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_MM); }
  | INS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_IN); }
  | PTS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_PT); }
  | PCS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_PC); }
  | DEGS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_DEG); }
  | RADS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_RAD); }
  | GRADS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_GRAD); }
  | TURNS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_TURN); }
  | MSECS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_MS); }
  | SECS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_S); }
  | HERTZ { $$.setFromNumber($1, CSSPrimitiveValue::CSS_HZ); }
  | KHERTZ { $$.setFromNumber($1, CSSPrimitiveValue::CSS_KHZ); }
  | EMS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_EMS); }
  | EXS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_EXS); }
  | CHS { $$.setFromNumber($1, CSSPrimitiveValue::CSS_CHS); }
  | VW { $$.setFromNumber($1, CSSPrimitiveValue::CSS_VW); }
  | VH { $$.setFromNumber($1, CSSPrimitiveValue::CSS_VH); }
  | VMIN { $$.setFromNumber($1, CSSPrimitiveValue::CSS_VMIN); }
  | VMAX { $$.setFromNumber($1, CSSPrimitiveValue::CSS_VMAX); }
  | DPPX { $$.setFromNumber($1, CSSPrimitiveValue::CSS_DPPX); }
  | DPI { $$.setFromNumber($1, CSSPrimitiveValue::CSS_DPI); }
  | DPCM { $$.setFromNumber($1, CSSPrimitiveValue::CSS_DPCM); }
  | FR { $$.setFromNumber($1, CSSPrimitiveValue::CSS_FR); }
  ;

function:
    FUNCTION maybe_space expr closing_parenthesis {
        $$.setFromFunction(parser->createFloatingFunction($1, parser->sinkFloatingValueList($3)));
    } |
    FUNCTION maybe_space closing_parenthesis {
        $$.setFromFunction(parser->createFloatingFunction($1, parser->sinkFloatingValueList(parser->createFloatingValueList())));
    } |
    FUNCTION maybe_space expr_recovery closing_parenthesis {
        YYERROR;
    }
  ;

calc_func_term:
  unary_term
  | unary_operator unary_term { $$ = $2; $$.fValue *= $1; }
  ;

calc_func_operator:
    space '+' space {
        $$ = '+';
    }
    | space '-' space {
        $$ = '-';
    }
    | calc_maybe_space '*' maybe_space {
        $$ = '*';
    }
    | calc_maybe_space '/' maybe_space {
        $$ = '/';
    }
  ;

calc_maybe_space:
    /* empty */
    | WHITESPACE
  ;

calc_func_paren_expr:
    '(' maybe_space calc_func_expr calc_maybe_space closing_parenthesis {
        $$ = $3;
        $$->insertValueAt(0, makeOperatorValue('('));
        $$->addValue(makeOperatorValue(')'));
    }
    | '(' maybe_space expr_recovery closing_parenthesis {
        YYERROR;
    }
  ;

calc_func_expr:
    calc_func_term {
        $$ = parser->createFloatingValueList();
        $$->addValue(parser->sinkFloatingValue($1));
    }
    | calc_func_expr calc_func_operator calc_func_term {
        $$ = $1;
        $$->addValue(makeOperatorValue($2));
        $$->addValue(parser->sinkFloatingValue($3));
    }
    | calc_func_expr calc_func_operator calc_func_paren_expr {
        $$ = $1;
        $$->addValue(makeOperatorValue($2));
        $$->stealValues(*($3));
    }
    | calc_func_paren_expr
  ;

calc_function:
    CALCFUNCTION maybe_space calc_func_expr calc_maybe_space closing_parenthesis {
        $$.setFromFunction(parser->createFloatingFunction($1, parser->sinkFloatingValueList($3)));
    }
    | CALCFUNCTION maybe_space expr_recovery closing_parenthesis {
        YYERROR;
    }
    ;


invalid_at:
    ATKEYWORD
    ;

at_rule_recovery:
    at_rule_header_recovery at_invalid_rule_header_end at_rule_end
    ;

at_rule_header_recovery:
    error error_location rule_error_recovery {
        parser->reportError($2, InvalidRuleCSSError);
    }
    ;

at_rule_end:
    at_invalid_rule_header_end semi_or_eof
  | at_invalid_rule_header_end invalid_block
    ;

regular_invalid_at_rule_header:
    before_font_face_rule FONT_FACE_SYM at_rule_header_recovery
  | before_supports_rule SUPPORTS_SYM error error_location rule_error_recovery {
        parser->reportError($4, InvalidSupportsConditionCSSError);
        parser->popSupportsRuleData();
    }
  | error_location invalid_at at_rule_header_recovery {
        parser->reportError($1, InvalidRuleCSSError);
    }
  ;

invalid_rule:
    error error_location rule_error_recovery at_invalid_rule_header_end invalid_block {
        parser->reportError($2, InvalidRuleCSSError);
    }
  | regular_invalid_at_rule_header at_invalid_rule_header_end ';'
  | regular_invalid_at_rule_header at_invalid_rule_header_end invalid_block
    ;

invalid_rule_header:
    error error_location rule_error_recovery at_invalid_rule_header_end {
        parser->reportError($2, InvalidRuleCSSError);
    }
  | regular_invalid_at_rule_header at_invalid_rule_header_end
    ;

at_invalid_rule_header_end:
   /* empty */ {
       parser->endInvalidRuleHeader();
   }
   ;

invalid_block:
    '{' error_recovery closing_brace {
        parser->invalidBlockHit();
    }
    ;

invalid_square_brackets_block:
    '[' error_recovery closing_square_bracket
    ;

invalid_parentheses_block:
    opening_parenthesis error_recovery closing_parenthesis;

opening_parenthesis:
    '(' | FUNCTION | CALCFUNCTION | NOTFUNCTION | HOSTFUNCTION
    ;

error_location: {
        $$ = parser->currentLocation();
    }
    ;

error_recovery:
    /* empty */
  | error_recovery error
  | error_recovery invalid_block
  | error_recovery invalid_square_brackets_block
  | error_recovery invalid_parentheses_block
    ;

rule_error_recovery:
    /* empty */
  | rule_error_recovery error
  | rule_error_recovery invalid_square_brackets_block
  | rule_error_recovery invalid_parentheses_block
    ;

%%
