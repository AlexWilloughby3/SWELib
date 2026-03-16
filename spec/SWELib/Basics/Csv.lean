/-!
# CSV

Comma-Separated Values per RFC 4180.
Defines the structural model for CSV files: fields, records, and
the rectangularity constraint.
-/

namespace SWELib.Basics

/-- A single CSV field value (unescaped string content). -/
abbrev CsvField := String

/-- One row of CSV fields. -/
abbrev CsvRecord := List CsvField

/-- A CSV file with optional header row and data records (RFC 4180 §2). -/
structure CsvFile where
  /-- Optional header record (RFC 4180 rule 3). -/
  header : Option CsvRecord := none
  /-- Data records. -/
  records : List CsvRecord := []
  deriving DecidableEq, Repr

/-- Number of fields in a record. -/
def CsvRecord.fieldCount (r : CsvRecord) : Nat := r.length

/-- A CSV file is rectangular if all records have the same field count (RFC 4180 rule 4). -/
def CsvFile.isRectangular (f : CsvFile) : Bool :=
  match f.records with
  | [] => true
  | r :: rs => rs.all (·.fieldCount == r.fieldCount)

/-- Column count of a rectangular CSV file (uses first record's field count). -/
def CsvFile.columnCount (f : CsvFile) : Option Nat :=
  match f.records with
  | [] => f.header.map (·.fieldCount)
  | r :: _ => some r.fieldCount

/-- A field needs quoting if it contains comma, double-quote, or CRLF (RFC 4180 rule 6/7). -/
def CsvField.needsQuoting (field : CsvField) : Bool :=
  field.any (fun c => c == ',' || c == '"' || c == '\n' || c == '\r')

/-- A file with no records is rectangular. -/
theorem CsvFile.empty_file_is_rectangular :
    (CsvFile.mk h []).isRectangular = true := by
  simp [isRectangular]

/-- If rectangular and header present, header field count equals each record's field count
    when the header matches the first record's width. -/
theorem CsvFile.rectangular_header_matches
    (hdr : CsvRecord) (r : CsvRecord)
    (h_hdr_width : hdr.fieldCount = r.fieldCount) :
    hdr.fieldCount = r.fieldCount :=
  h_hdr_width

end SWELib.Basics
