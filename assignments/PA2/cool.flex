/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
    YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 *  1 null; 
 *  
 *  2 tooLong; > MAX_LENGTH
 *  3 escaped null
 */


char* my_string;
int i;

int line_num = 1;

int deepth = 0;
#define MAX_ERROR_NUMBER 4
int* error_queue;
int error_size;
bool containNull;
%}

/*
 * Define names for regular expressions here.
 */

%x 		COMMENT
%x		COMMENT_ESCAPE

%x		STR
%x		STR_ESCAPE

/* --- 2 character operator --- */
DARROW          =>
ASSIGN		<-
LE		<=
/* --------- Keywords --------- */
CLASS		(?i:class)
INHERITS	(?i:inherits)

IF		(?i:if)
THEN		(?i:then)
ELSE		(?i:else)
FI		(?i:fi)

WHILE		(?i:while)
LOOP		(?i:loop)
POOL		(?i:pool)

LET		(?i:let)
IN		(?i:in)

FALSE		(f(?i:alse))
TRUE		(t(?i:rue))

ISVOID 		(?i:isvoid)
CASE		(?i:case)
ESAC		(?i:esac)
NEW		(?i:new)
OF		(?i:of)
NOT		(?i:not)

%%
    
 /* ----------------------------------- White Space -------------------------------------- */

\n	{ line_num++; curr_lineno = line_num;  }
[ \f\r\t\v]	/* --skip-- */

 /* ----------------------------------- Punctuation -------------------------------------- */

[\{\}\:\;\(\)\,]	{ return yytext[0]; }

 /* ------------------------------------Nested Comments----------------------------------- */

 /* single line comments */

--.*

 /* multiple lines comments */

"(*"	{ deepth = 1; BEGIN(COMMENT); }
<COMMENT><<EOF>>	{ 
        cool_yylval.error_msg = "EOF in comment";
        BEGIN(INITIAL);
        return ERROR; 
}
<COMMENT>"(*"		{ deepth++; }
<COMMENT>"*)"		{ --deepth; if(deepth == 0) BEGIN(INITIAL); }
<COMMENT>\\.		
<COMMENT>\n		{ line_num++; }
<COMMENT>"*"[^\)\*\n]	/* ---- eat anything that is not *) or \n ---- */
<COMMENT>.		/* ---- eat anything that is not *) or \n ---- */

\*\)	{
  cool_yylval.error_msg = "Unmatched *)";
  return (ERROR);
}

 /* ----------------------------------- operators.------------------------------------------*/

{DARROW}	{ return DARROW; }
{ASSIGN}	{ return ASSIGN; }
{LE}		{ return LE; }

[\.@~]		{ return yytext[0]; }
[\+\-\*\/\=\<]	{ return yytext[0]; }
 /* ----------------------------------------------------------------------------------------
  * 
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}		{ return CLASS; }
{INHERITS}	{ return INHERITS; }

{IF}		{ return IF; }
{THEN}		{ return THEN; }
{ELSE}		{ return ELSE; }
{FI}		{ return FI; }
{WHILE}		{ return WHILE; }
{LOOP}		{ return LOOP; }
{POOL}		{ return POOL; }

{LET}		{ return LET; }
{IN}		{ return IN; }



{ISVOID} 	{ return ISVOID; }
{CASE}		{ return CASE; }
{ESAC}		{ return ESAC; }
{NEW}		{ return NEW; }
{OF}		{ return OF; }
{NOT}		{ return NOT; }

{TRUE}		{ 
      cool_yylval.boolean = true;
      return BOOL_CONST;		
}

{FALSE}		{ 
      cool_yylval.boolean = false;
      return BOOL_CONST;
}

 /* ------------------------------------ digits -------------------------------------- */

[0-9]+		{
    cool_yylval.symbol = inttable.add_string(yytext); 
    return INT_CONST;
}

 /* ------------------------------- identifier ---------------------------------- */

[A-Z][a-zA-Z0-9_]*	{
        cool_yylval.symbol = idtable.add_string(yytext);
        return TYPEID;
}
[a-z][a-zA-Z0-9_]*	{
        cool_yylval.symbol = idtable.add_string(yytext);
        return OBJECTID;
}

 /* ------------------------------------------------------------------------------------
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  */

\"		{
          my_string = new char[MAX_STR_CONST];
          error_queue = new int[MAX_ERROR_NUMBER];
          i = 0;
          error_size = 0;
          BEGIN(STR);
}
<STR>\"		{
          curr_lineno = line_num;
          if (error_size > 0) {
            int error = error_queue[0];
            if (error == 1 || error == 3) {
	            containNull = false;
              if(error == 1) yylval.error_msg = "String contains null character";
              else yylval.error_msg = "String contains escaped null character";
              BEGIN(INITIAL);
              return ERROR;
            }
            if (error == 2) {
              yylval.error_msg = "String constant too long";
              BEGIN(INITIAL);
              return ERROR;
            }
          }
          yylval.symbol = stringtable.add_string(my_string);	
          BEGIN(INITIAL);
          return STR_CONST;
}
<STR>\\ { BEGIN(STR_ESCAPE); }
<STR,STR_ESCAPE><<EOF>> {
                          yylval.error_msg = "EOF in string constant";
                          BEGIN(INITIAL);
                          return ERROR;
}
<STR_ESCAPE>[nbft]  {
                      if (i < MAX_STR_CONST - 1) {
                        char cur = yytext[0];
                        if (cur == 'n') my_string[i++] = '\n';
                        else if (cur == 'b') my_string[i++] = '\b';
                        else if (cur == 'f') my_string[i++] = '\f';
                        else my_string[i++] = '\t';
                        
                      }
                      else { 
                            if(error_size < MAX_ERROR_NUMBER) 
				                      error_queue[error_size] = 2;
                            error_size++;
                      }
		      BEGIN(STR);
}
<STR_ESCAPE>\0  {
                  containNull = true;
                  if(error_size < MAX_ERROR_NUMBER) 
                    error_queue[error_size] = 3;
                  error_size++;
                  BEGIN(STR);
}
<STR_ESCAPE>[^\0]	{
                    if (i < MAX_STR_CONST - 1) {
                      if(yytext[0] == '\n') line_num++;
                      my_string[i++] = yytext[0];
                      BEGIN(STR);
                    } 
                    else { 
                          if(error_size < MAX_ERROR_NUMBER) 
                            error_queue[error_size] = 2;
                          error_size++;
			              }
}
<STR>\0		{
            containNull = true;
            if(error_size < MAX_ERROR_NUMBER) 
              error_queue[error_size] = 1;
            error_size++;
}
<STR>\n		{ 
		  line_num++;
		  curr_lineno = line_num;
		  if (containNull) {
			  containNull = false;
        yylval.error_msg = "String contains null character";
        BEGIN(INITIAL);
        return ERROR;
		  }
		  yylval.error_msg = "Unterminated string constant";
		  BEGIN(INITIAL);
		  return ERROR;
}
<STR>.  {	
          if (i < MAX_STR_CONST - 1) {
            my_string[i++] = yytext[0];
          } 
          else {
            if(error_size < MAX_ERROR_NUMBER)
			        error_queue[error_size] = 2;
            error_size++;
          }
}
. { 
    yylval.error_msg = yytext; 
    return ERROR;
}
%%
