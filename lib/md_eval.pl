/*  Part of SWISH

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@cs.vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2018, VU University Amsterdam
			 CWI Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(md_eval,
          [ html/1,                     % +Spec
            safe_html/1,                % +Spec
            safe_html//1                % +Spec
          ]).
:- use_module(library(modules)).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(debug)).
:- use_module(library(option)).
:- use_module(library(occurs)).
:- use_module(library(settings)).
:- use_module(library(error)).
:- use_module(library(pldoc/doc_wiki)).
:- use_module(library(http/html_write)).
:- use_module(library(dcg/basics)).
:- use_module(library(sandbox)).
:- use_module(library(time)).

:- setting(md_eval_time_limit, number, 10,
           "Timit limit for evaluating a ```{eval} cell").

/** <module> Provide evaluable markdown

This  module  adds  evaluable  sections  to   markdown  cells  in  SWISH
notebooks. Such cells are written as

  ==
  ```{eval}
  <Prolog code>
  ```
  ==
*/

%!  eval_dom(+DOM0, -DOM, +Options) is semidet.
%
%   This predicate post-processes  the  wiki  DOM   result  if  the  DOM
%   contains at least one  `eval`  code   fragment.  The  evaluation  is
%   executed  in  a  sandboxed  environment,   much  like  the  Pengines
%   infrastructure.
%
%   A code fragment is represented by a term of this shape:
%
%       pre([class(code), ext(Ext)], Text)

eval_dom(DOM0, DOM, Options) :-
    contains_eval(DOM0),
    !,
    in_temporary_module(
        Module,
        prepare(Module),
        md_eval(Module, Options, DOM0, DOM, 0, _)).

prepare(Module) :-
    setting(swish:program_space, SpaceLimit),
    set_module(Module:program_space(SpaceLimit)),
    delete_import_module(Module, user),
    add_import_module(Module, swish, start).

%!  md_eval(+Module, +Options, +DOM0, -DOM, +FragI0, -FragI1)

md_eval(Module, Options, Pre, Evaluated, I0, I) :-
    pre(Pre, eval, Code),
    !,
    eval(Module, I0, Code, Evaluated, Options),
    I is I0 + 1.
md_eval(Module, Options, Compound, Evaluated, I0, I) :-
    compound(Compound),
    !,
    compound_name_arguments(Compound, Name, Args0),
    foldl(md_eval(Module, Options), Args0, Args, I0, I),
    compound_name_arguments(Evaluated, Name, Args).
md_eval(_, _, DOM, DOM, I, I) :-
    !.

:- meta_predicate
    call_collect_messages(0, -).

eval(Module, I, Code, div(class(eval), Evaluated), Options) :-
    option(time_limit(Limit), Options, 10),
    catch(( call_collect_messages(
                call_with_time_limit(
                    Limit,
                    do_eval(Module, I, Code, Evaluated0, Options)),
                Messages),
            append(Evaluated0, Messages, Evaluated)
          ),
          Error,
          failed(Error, Evaluated)).

do_eval(Module, I, Code, [div(class(output), DOM)], _Options) :-
    debug(md(eval), 'Evaluating ~p', [Code]),
    format(atom(Id), 'eval://~w-~w', [Module, I]),
    with_output_to(
        codes(Codes),
        setup_call_cleanup(
            open_string(Code, In),
            load_files(Module:Id,
                       [ stream(In),
                         sandboxed(true)
                       ]),
            close(In))),
    eval_to_dom(Codes, DOM).

eval_to_dom(Codes, DOM) :-
    phrase(is_html, Codes),
    E = error(_,_),
    catch(setup_call_cleanup(
              open_string(Codes, In),
              load_html(In, DOM, []),
              close(In)),
          E, fail),
    !.
eval_to_dom(Codes, DOM) :-
    wiki_codes_to_dom(Codes, [], DOM).

is_html -->
    blanks, "<", tag(Tag),
    string(_),
    "</", tag(Tag), ">", blanks.

tag([H|T]) -->
    alpha(H),
    alphas(T).

alpha(H) -->
    [H],
    { between(0'a, 0'z, H) }.

alphas([H|T]) -->
    alpha(H),
    !,
    alphas(T).
alphas([]) -->
    [].

contains_eval(DOM) :-
    sub_term(Pre, DOM),
    pre(Pre, eval, _),
    !.

pre(pre(Attrs, Text), Ext, Text) :-
    memberchk(ext(Ext), Attrs).

:- thread_local
    saved_message/1.

failed(Error, [div(class(error), Message)]) :-
    message_to_string(Error, Message).

call_collect_messages(Goal, Messages) :-
    setup_call_cleanup(
        asserta((user:thread_message_hook(Term, Kind, Lines) :-
                   save_message(Term, Kind, Lines)), Ref),
        Goal,
        collect_messages(Ref, Messages)).

save_message(_Term, Kind, Lines) :-
    kind_prefix(Kind, Prefix),
    with_output_to(
        string(Msg),
        print_message_lines(current_output, Prefix, Lines)),
    assertz(saved_message(pre(class([eval,Kind]), Msg))).

kind_prefix(error,   '% ERROR: ').
kind_prefix(warning, '% Warning: ').

collect_messages(Ref, Messages) :-
    erase(Ref),
    findall(Msg, retract(saved_message(Msg)), Messages).


		 /*******************************
		 *         OTHER OUTPUTS	*
		 *******************************/

%!  html(+Spec) is det.
%
%   Include HTML into the output.

:- html_meta
    html(html),
    safe_html(html),
    safe_html(html,?,?).

html(Spec) :-
    phrase(html(div(Spec)), Tokens),
    with_output_to(
        string(HTML),
        print_html(current_output, Tokens)),
    format('~w', [HTML]).

safe_html(Spec) :-
    is_safe_html(Spec),
    !,
    html(Spec).

safe_html(Spec) -->
    { is_safe_html(Spec) },
    !,
    html(Spec).

is_safe_html(M:Spec) :-
    prolog_load_context(module, M),
    must_be(ground, Spec),
    forall(sub_term(\(Eval), Spec),
           safe_eval(Eval, M)).

safe_eval(Goal, M) :-
    dcg_extend(Goal, DcgGoal),
    safe_goal(M:DcgGoal).

dcg_extend(Goal, DcgGoal) :-
    must_be(callable, Goal),
    Goal \= (_:_),
    Goal =.. List,
    append(List, [_,_], ExList),
    DcgGoal =.. ExList.

swish:goal_expansion(html(Spec), safe_html(Spec)).
swish:goal_expansion(html(Spec, L,T), safe_html(Spec, L, T)).

:- multifile sandbox:safe_primitive/1.

sandbox:safe_meta_predicate(md_eval:safe_html/1).
sandbox:safe_meta_predicate(md_eval:safe_html/3).
sandbox:safe_primitive(md_eval:html(Spec)) :-
    \+ sub_term(\(_), Spec).
sandbox:safe_meta_predicate(md_eval:is_safe_html/1).


		 /*******************************
		 *           ACTIVATE		*
		 *******************************/

:- multifile
    swish_markdown:dom_expansion/2.

swish_markdown:dom_expansion(DOM0, DOM) :-
    setting(md_eval_time_limit, Limit),
    Limit > 0,
    eval_dom(DOM0, DOM, [time_limit(Limit)]).
