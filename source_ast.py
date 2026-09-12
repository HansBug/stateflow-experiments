"""Use the pinned MARS Stateflow grammar and AST, with explicit dialect productions."""
from pathlib import Path
import sys
from lark import Lark, v_args
from lark.exceptions import UnexpectedInput

sys.path.insert(0, str(Path(__file__).parent / '_external/mars'))
from ss2hcsp.matlab import function as sf
from ss2hcsp.matlab.parser import grammar, MatlabTransformer

# These are grammar alternatives, not substitutions on user expressions.
# MARS already defines the ineq_cond AST constructor for the != spelling.
EXTENSIONS = r'''
%extend atom_cond: expr "~=" expr -> ineq_cond
    | expr "<>" expr -> ineq_cond
%extend state_op: lname "/" (entry_op)? (during_op)? (exit_op)? -> state_op
'''


class CheckedTransformer(MatlabTransformer):
    @v_args(inline=True)
    def state_op(self, *args):
        # Upstream drops a single unlabelled Assign here while treating a
        # Sequence as entry code. Reject both rather than silently lose actions
        # or assign a lifecycle role without a source declaration.
        if any(isinstance(arg, sf.Command) for arg in args):
            raise ValueError('Unlabelled state actions are outside this import profile')
        return super().state_op(*args)


PARSER = Lark(grammar + EXTENSIONS, start=['expr', 'transition', 'state_op'],
              parser='lalr', transformer=CheckedTransformer())


class SourceParserError(ValueError):
    pass


def parse(text, start):
    try:
        return PARSER.parse(text, start=start)
    except (UnexpectedInput, TypeError, ValueError, AssertionError) as error:
        # UnexpectedInput: MARS grammar rejection; TypeError/AssertionError:
        # its transformer rejects an AST shape; ValueError: numeric token
        # conversion. Catch only around the external parser call.
        raise SourceParserError(type(error).__name__ + ': ' + str(error)) from error
