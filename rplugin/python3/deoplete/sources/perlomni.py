from .base import Base
import deoplete.util


class Source(Base):

    def __init__(self, vim):
        Base.__init__(self, vim)
        self.name = 'PerlOmni'
        self.mark = '[P]'
        self.min_pattern_length = 1
        self.is_bytepos = 'True'
        self.rank = 101
        self.filetypes = ['perl']

    def get_complete_position(self, context):
        try:
            complete_pos = self.vim.call('PerlComplete', 1, '')
        except:
            return -1
        return complete_pos

    def gather_candidates(self, context):

        values = self.vim.call('PerlComplete', 0, context['complete_str'])
        # self.debug(type(values).__name__)

        if isinstance(values, list) and len(values) > 0 and isinstance(values[0], str):
            ret = []
            for x in values:
                # self.debug(type(x).__name__)
                if isinstance(x, str):
                    ret.append({'word': x})
                else:
                    ret.append(x)
            # self.debug(ret)
            return ret
        return values
