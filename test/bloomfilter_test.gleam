import gleeunit
import gleeunit/should
import internal/header

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn simple_encoding() {
  header.encode_header(header.Header(8, 1000, 12))
  |> should.equal(<<8, 0, 0, 0, 0, 0, 0, 3, 232, 12>>)
}

pub fn simple_decoding() {
  case header.decode_header(<<8, 0, 0, 0, 0, 0, 0, 3, 232, 12>>) {
    Ok(p) -> p
    _ -> header.Header(0, 0, 0)
  }
  |> should.equal(header.Header(8, 1000, 12))
}
