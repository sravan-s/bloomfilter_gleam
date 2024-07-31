import gleam/bit_array
import gleam/list

pub type Header {
  Header(version: Int, bloom_filter_size: Int, hash_fns_count: Int)
}

pub type HeaderErrors {
  DecodeError
}

// save upto 2^8 = 256
const v_size = 8

// save upto 2^64
const bf_size = 64

// save upto 2^8 = 256
const hfn_size = 8

// an unoptimal power fn for Ints; donot reuse
// only works when exp >= 0
fn pow(base: Int, exp: Int) -> Int {
  case exp {
    0 -> 1
    x if x > 0 -> base * pow(base, exp - 1)
    _ -> 1
  }
}

// <<a1, ..., a8>> = a1*(2^56) + .... + a7*(2^8)+ a8*(2^0)
fn calculate_buffer_size(array: List(Int)) -> Int {
  let size = list.length(array) - 1
  case array {
    [] -> 0
    [a] -> a
    [a, ..rest] -> { a * pow(2, size * 8) } + calculate_buffer_size(rest)
  }
}

pub fn decode_header(array: BitArray) -> Result(Header, HeaderErrors) {
  case array {
    <<version, bf1, bf2, bf3, bf4, bf5, bf6, bf7, bf8, hfn>> -> {
      let bf = calculate_buffer_size([bf1, bf2, bf3, bf4, bf5, bf6, bf7, bf8])
      Ok(Header(version: version, bloom_filter_size: bf, hash_fns_count: hfn))
    }
    _ -> Error(DecodeError)
  }
}

pub fn encode_header(h: Header) -> BitArray {
  let version = <<h.version:size(v_size)>>
  let bloom_filter_size = <<h.bloom_filter_size:size(bf_size)>>
  let hash_size = <<h.hash_fns_count:size(hfn_size)>>

  version
  |> bit_array.append(bloom_filter_size)
  |> bit_array.append(hash_size)
}
