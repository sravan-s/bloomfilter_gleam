import gleeunit
import gleeunit/should
import internal/build_filter
import internal/header

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn simple_encoding_test() {
  header.encode_header(header.Header(8, 1000, 12))
  |> should.equal(<<8, 0, 0, 0, 0, 0, 0, 3, 232, 12>>)
}

pub fn simple_decoding_test() {
  case header.decode_header(<<8, 0, 0, 0, 0, 0, 0, 3, 232, 12>>) {
    Ok(p) -> p
    _ -> header.Header(0, 0, 0)
  }
  |> should.equal(header.Header(8, 1000, 12))
}

pub fn right_padding_one_test() {
  build_filter.right_padding([1, 1, 1])
  |> should.equal([1, 1, 1, 0, 0, 0, 0, 0])
}

pub fn right_padding_two_test() {
  build_filter.right_padding([])
  |> should.equal([0, 0, 0, 0, 0, 0, 0, 0])
}

pub fn right_padding_three_test() {
  build_filter.right_padding([0, 0, 1, 0])
  |> should.equal([0, 0, 1, 0, 0, 0, 0, 0])
}

pub fn right_padding_four_test() {
  build_filter.right_padding([0, 0, 1, 0, 0, 0, 0, 0])
  |> should.equal([0, 0, 1, 0, 0, 0, 0, 0])
}

pub fn list_to_bitarray_one_test() {
  build_filter.list_to_bitarray([0, 0, 0, 0, 0, 0, 0, 1])
  |> should.equal(<<1:size(8)>>)
}

pub fn list_to_bitarray_two_test() {
  build_filter.list_to_bitarray([])
  |> should.equal(<<>>)
}
