"""
----------------------------------------------
IKE
csv2locale.py
----------------------------------------------

Generates a Lua table from a CSV containing text
translations.

Usage:

   python csv2locale.py infile.csv French
   
----------------------------------------------
"""

import sys
import csv

# CSV DATABASE QUERIES
class db:
   # create a dictionary from a CSV
   def load(csvFile):
      dr = None
      with open(csvFile, newline='', encoding='utf8') as cvf:
         dr = list(csv.DictReader(cvf, delimiter="|"))
      # convert strings to numbers where appropriate
      for e in dr:
         for k,v in e.items():
               if v.isnumeric():
                  if v.find(".") != -1:
                     e[k] = float(v)
                  else:
                     e[k] = int(v)
      return db(dr)

   def __init__(self, data=None):
      # Make sure the DB is initialized from new memory
      if data == None:
         self.data = []
      else:
         self.data = data

   def __iter__(self):
      return iter(self.data)
   
   def __len__(self):
      return len(self.data)

   def __delitem__(self, index):
      self.data.__delitem__(index)

   def insert(self, index, value):
      self.data.insert(index, value)

   def __setitem__(self, index, value):
      self.data.__setitem__(index, value)

   def __getitem__(self, index):
      result = self.data.__getitem__(index)
      if isinstance(result, list):
         return db(result)
      return result

   def sort(self, keyFunc):
      self.data.sort(key=keyFunc)

   def getIndex(self, i):
      return self.data[i]

   def append(self, e):
      self.data.append(e)

   # copy DB and execute a function on each element
   def transform(self, executeFunc):
      elements = self.data.copy()
      for element in elements:
         executeFunc(element)
      return db(elements)
   
   # execute a function on each element of DB in place
   def transformInPlace(self, executeFunc):
      elements = self.data
      for element in elements:
         executeFunc(element)

   # return results filtered by a query function
   def query(self, queryFunc):
      results = []
      for element in self:
         if queryFunc(element):
               results.append(element.copy())
      return db(results)

   # return first element matching query function
   def findFirst(self, queryFunc):
      for element in self:
         if queryFunc(element):
               return element
      return None

# DB Fields: ID, Text

def start_defs(f, csvfile, lan):
   f.write(f"-- EXPORTED FROM {csvfile}\n\n")
   f.write("LOCALIZATION = {\n")
   f.write(f"\t[\"{lan}\"] = {{\n")

def add_translation(f, id, trans, line_num):
   if line_num > 0:
      f.write(",\n")
   f.write(f"\t\t[\"{id}\"] = \"{trans.rstrip()}\"")

def end_defs(f):
   f.write("\n\t}\n}\n")

if __name__ == "__main__":
   if len(sys.argv) < 2:
        print("You must specify a CSV file!")
        sys.exit()
   if len(sys.argv) < 3:
        print("You must specify a language name!")
        sys.exit()
   
   csv_file = sys.argv[1]
   lang_name = sys.argv[2]

   csv_db = db.load(csv_file)
   export_file = f"locale/{lang_name}_locale.lua"

   with open(export_file, 'w') as file:
      start_defs(file, csv_file, lang_name)
      line_num = 0
      for item in csv_db:
            add_translation(
               file,
               item['ID'],
               item['Text'],
               line_num
            )
            line_num = line_num + 1
      end_defs(file)
   print(f"{lang_name} localization written to {export_file}.")