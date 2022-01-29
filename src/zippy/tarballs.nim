import common, internal, std/memfiles, std/os, std/times, tarballs_v1, zippy

export common, tarballs_v1

import strutils

proc parseTarOctInt(s: string): int =
  try:
    if s[0] == '\0':
      0
    else:
      parseOctInt(s)
  except ValueError:
    raise currentExceptionAsZippyError()

proc extractAll*(
  tarPath, dest: string
) {.raises: [IOError, OSError, ZippyError].} =
  ## Extracts the files stored in tarball to the destination directory.
  ## The path to the destination directory must exist.
  ## The destination directory itself must not exist (it is not overwitten).
  if dest == "" or dirExists(dest):
    raise newException(ZippyError, "Destination " & dest & " already exists")

  var (head, tail) = splitPath(dest)
  if tail == "": # For / at end of path
    (head, tail) = splitPath(head)
  if head != "" and not dirExists(head):
    raise newException(ZippyError, "Path to " & dest & " does not exist")

  var uncompressed: string
  block:
    var memFile = memfiles.open(tarPath)
    try:
      if memFile.size < 2:
        failUncompress()

      let src = cast[ptr UncheckedArray[uint8]](memFile.mem)
      if src[0] == 31 and src[1] == 139:
        # Looks like a compressed tarball (.tar.gz)
        uncompressed = uncompress(src, memFile.size, dfGzip)
      else:
        # Treat this as an uncompressed tarball (.tar)
        uncompressed.setLen(memFile.size)
        copyMem(uncompressed[0].addr, src, memFile.size)
    finally:
      memFile.close()

  try:
    var lastModifiedTimes: seq[(string, Time)]

    var pos: int
    while pos < uncompressed.len:
      if pos + 512 > uncompressed.len:
        failArchiveEOF()

      # See https://www.gnu.org/software/tar/manual/html_node/Standard.html

      let
        name = $(uncompressed[pos ..< pos + 100]).cstring
        mode = parseTarOctInt(uncompressed[pos + 100 ..< pos + 100 + 7])
        size = parseTarOctInt(uncompressed[pos + 124 ..< pos + 124 + 11])
        mtime = parseTarOctInt(uncompressed[pos + 136 ..< pos + 136 + 11])
        typeflag = uncompressed[pos + 156]
        magic = $(uncompressed[pos + 257 ..< pos + 257 + 6]).cstring
        prefix =
          if magic == "ustar":
            $(uncompressed[pos + 345 ..< pos + 345 + 155]).cstring
          else:
            ""

      pos += 512

      if pos + size > uncompressed.len:
        failArchiveEOF()

      if name.len > 0:
        let path = prefix / name
        path.verifyPathIsSafeToExtract()

        if typeflag == '0' or typeflag == '\0':
          createDir(dest / splitFile(path).dir)
          writeFile(
            dest / path,
            uncompressed.toOpenArray(pos, max(pos + size - 1, 0))
          )
          setFilePermissions(dest / path, parseFilePermissions(mode))
          lastModifiedTimes.add (path, initTime(mtime, 0))
        elif typeflag == '5':
          createDir(dest / path)
          lastModifiedTimes.add (path, initTime(mtime, 0))
        elif typeflag in ['g', 'x']:
          discard
        else:
          raise newException(ZippyError, "Unsupported header type " & typeflag)

      pos += (size + 511) and not 511

    # Set last modification time as a second pass otherwise directories get
    # updated last modification times as files are added on Mac.
    for (path, lastModified) in lastModifiedTimes:
      if lastModified > Time():
        setLastModificationTime(dest / path, lastModified)

  # If something bad happens delete the destination directory to avoid leaving
  # an incomplete extract.
  except IOError as e:
    removeDir(dest)
    raise e
  except OSError as e:
    removeDir(dest)
    raise e
  except ZippyError as e:
    removeDir(dest)
    raise e
