import std/os, zippy/ziparchives, std/tables, std/strutils

# var entries: OrderedTable[string, string]
# entries["a/b/tmp.txt"] = "a text file's contents here"

# let archive = createZipArchive(entries)
# echo archive.len
# writeFile("tmp.zip", archive)

# let reader = openZipArchive("tmp.zip")

# try:
#   # Iterate over the paths in the zip archive.
#   for path in reader.walkFiles:
#     echo path

#   # # Extract a file from the archive.
#   let contents = reader.extractFile("a/b/tmp.txt")
#   echo contents.len
# finally:
#   # Remember to close the reader when done.
#   reader.close()

# var entries: OrderedTable[string, string]
# for path in walkDirRec(getCurrentDir(), relative = true, skipSpecial = true):
#   if path.startsWith(".git"):
#     continue
#   if path.endsWith(".exe"):
#     continue
#   entries[path] = readFile(path)
# writeFile("tmp.zip", createZipArchive(entries))
