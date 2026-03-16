import SWELib.Cloud.OciImage

open SWELib.Cloud.OciImage

-- Test basic types compile and work
def test1 : Algorithm := Algorithm.sha256
def test2 : MediaType := mediaTypeImageConfig
def test3 : Platform := Platform.linuxAmd64

-- Test smart constructors
def testDigest : Option Digest :=
  Digest.sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

-- Create simple annotations
def testAnnotations : Annotations := [
  (annotationTitle, "Test Image"),
  (annotationVersion, "1.0.0")
]

#eval test1
#eval test2
#eval test3.architecture
#eval testDigest.isSome
#eval testAnnotations.get annotationTitle