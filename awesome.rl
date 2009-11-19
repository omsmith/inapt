#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <vector>

using namespace std;

#define xstrndup strndup

%%{
    machine inapt;

    action pkgstart { ts = p; }
    action pkgend { te = p; }

    action add_list {
      tmp_list.push_back(xstrndup(ts, te-ts+1));
    }

    action clear_list {
      while (tmp_list.size()) {
        free(tmp_list.back());
        tmp_list.pop_back();
      }
    }

    action install {
      for (vector<char *>::iterator i = tmp_list.begin(); i < tmp_list.end(); i++)
        add_list.push_back(*i);
      tmp_list.clear();
    }

    action remove {
      for (vector<char *>::iterator i = tmp_list.begin(); i < tmp_list.end(); i++)
        del_list.push_back(*i);
      tmp_list.clear();
    }

    package_name = ((lower | digit) (lower | digit | '+' | '-' | '.')+) >pkgstart @pkgend;
    package_list = ((space+ package_name)+ %add_list space*) >clear_list;
    cmd_install = 'install' package_list ';' @install;
    cmd_remove = 'remove' package_list ';' @remove;

    main := (cmd_install | cmd_remove | space)*;
}%%

%% write data nofinal;

#define BUFSIZE 128

void scanner(vector<char *> &add_list, vector<char *> &del_list)
{
    static char buf[BUFSIZE];
    int cs, have = 0;
    int done = 0;
    char *ts = 0, *te = 0;

    vector<char *> tmp_list;

    %% write init;

    while ( !done ) {
        char *p = buf + have, *pe, *eof = 0;
        int len, space = BUFSIZE - have;

        if ( space == 0 ) {
            /* We've used up the entire buffer storing an already-parsed token
             * prefix that must be preserved. */
            fprintf(stderr, "OUT OF BUFFER SPACE\n" );
            exit(1);
        }

        len = fread(p, 1, space, stdin);
        pe = p + len;

        /* Check if this is the end of file. */
        if ( len < space ) {
            eof = pe;
            done = 1;
        }

        %% write exec;

        if ( cs == inapt_error ) {
            fprintf(stderr, "PARSE ERROR\n" );
            break;
        }

        have = 0;

        if (ts) {
            have = pe -ts;
            memmove(buf, ts, have);
            te = buf + (te - ts);
            ts = buf;
        }
    }
}

int main()
{
    vector<char *> add_list;
    vector<char *> del_list;
    scanner(add_list, del_list);
    for (vector<char *>::iterator i = add_list.begin(); i < add_list.end(); i++)
      printf("install %s\n", *i);
    for (vector<char *>::iterator i = del_list.begin(); i < del_list.end(); i++)
      printf("remove %s\n", *i);
    return 0;
}
