%{
  #include<stdio.h>
  #include<math.h>
  #include<calc.h>
  int yylex (void);
  void yyerror (char const *);
%}

/*
 * @api.value.type: 指定token的数据类型
*/
%define api.value.type { double }
%token NUM
%token <symrec*> VAR FUN 
%nterm <double> exp


%precedence '='
%left '-' '+'
%left '*' '/'
%precedence NEG
%right '^'




// yyparse will parse the rule below
%%
input: // S -> epsilon | SA
  %empty 
| input line 
;

line: // A -> '\n' | B'\n'
  '\n'      /* no action will be done */
| exp '\n'  { printf("%.10g\n", $1); }
| error '\n'  { yyerrok; }
/* none in rules of line return a value, therefor
 * the value of line is unpredictable and random
*/
;

exp: 
  NUM
| VAR         { $$ = $1 -> value.var; }
| VAR '=' exp { $$ = $3; $1 -> value.var = $3; }
| FUN '(' exp ')' { $$ = $1->value.fun($3); }
| exp '+' exp { $$ = $1 + $3; }
| exp '-' exp { $$ = $1 - $3; }
| exp '*' exp { $$ = $1 * $3; }
| exp '/' exp {
                if ($3) $$ = $1 / $3; 
                else {
                  $$ = 1;
                  fprintf(stderr, "%d.%d-%d.%d: division by 0",
                          @3.first_line, @3.first_column,
                          @3.last_line, @3.last_column);
                }
              }
| '-' exp %prec NEG { $$ = -$2; }
| exp '^' exp { $$ = pow($1, $3); }
| '(' exp ')' { $$ = $2; }
| exp 'n' { $$ = -$1; }
;
/* if a rule don't have action, 
 * Bison execute $$ = $1; by default 
 */
%%