"""
----------------------------------------------
IKE
escape.py
----------------------------------------------

String escaper for generating the loader string.
Produces an escaped string suitable for injection
into a CMO LuaScript event action.

Usage:

   python escape.py infile.txt outfile.txt
   
----------------------------------------------
"""

import sys

replacetables = [
    {
        # first, escape existing slashes
        "\\":"\\\\",
    },
    {
        # then add slashes to escape chars
        "\"":"\\\"",
        "\f":"\\f",
        "\r":"\\r",
        "\t":"\\t",
        "\n":"\\r\\n",
        "\b":"\\b",
    }
]

if __name__ == "__main__":
    filename = sys.argv[1]
    outname = sys.argv[2]
    f = open(filename, 'r')
    
    # read from the in file
    text = f.read().rstrip()
    
    # proceed in order, replacing strings
    for table in replacetables:
        for key,val in table.items():
            text = text.replace(key, val)

    # write to the outfile
    o = open(outname,'w')
    o.write("\""+text+"\"\n\n")