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

replace_table = {
    "\"":"\\\"",
    "\f":"\\f",
    "\r":"\\r",
    "\t":"\\t",
    "\n":"\\r\\n",
    "\b":"\\b",
}

if __name__ == "__main__":
    filename = sys.argv[1]
    outname = sys.argv[2]
    f = open(filename, 'r')
    
    # read from the in file
    text = f.read().rstrip()
    
    # escape strings
    for key,val in replace_table.items():
        text = text.replace(key, val)
    
    # escape slashes
    index = 0
    while index != -1:
        index = text.find("\\", index)
        if index != -1:
            selection = text[index:index+2]
            if (not selection in replace_table.values()) and text[index-1] != 'r':
                text = text[:index] + "\\\\" + text[index+1:]
                index = index+2
            else:
                index = index+1
            
    # write to the outfile
    o = open(outname,'w')
    o.write("\""+text+"\"\n\n")