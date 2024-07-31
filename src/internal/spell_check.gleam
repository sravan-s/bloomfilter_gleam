import file_streams/file_stream
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import internal/build_filter
import internal/header

fn read_filter(handle: file_stream.FileStream) -> #(header.Header, BitArray) {
  let header = case file_stream.read_bytes(handle, header.get_header_size()) {
    Ok(line) -> header.decode_header(line)
    Error(e) -> {
      let error_message = "Couldnt read header: "
      io.debug(e)
      panic as error_message
    }
  }
  let header = case header {
    Ok(h) -> h
    Error(e) -> {
      let error_message = "Couldnt decode header: "
      io.debug(e)
      panic as error_message
    }
  }
  let body = case file_stream.read_bytes(handle, header.bloom_filter_size) {
    Ok(line) -> line
    Error(e) -> {
      let error_message = "Couldnt read body of bllomfilter: "
      io.debug(e)
      panic as error_message
    }
  }
  #(header, body)
}

fn get_hashes(
  word: String,
  max_bound: Int,
  iters: Int,
  accum: List(Int),
) -> List(Int) {
  let hashed = build_filter.hash(word, max_bound, iters)
  case iters {
    0 -> [hashed]
    _ -> [hashed, ..get_hashes(word, max_bound, iters - 1, accum)]
  }
}

// <<1, 7>> = [1, 7]
@external(erlang, "binary", "bin_to_list")
fn bin_to_list(bytes: BitArray, start: Int, end: Int) -> List(Int)

@external(erlang, "erlang", "integer_to_list")
fn integer_to_list(num: Int, base: Int) -> String

@external(erlang, "lists", "nth")
fn nth(n: Int, list: List(Int)) -> Int

fn pad(a: List(Int)) -> List(Int) {
  let size = list.length(a)
  case size {
    8 -> a
    _ -> pad([0, ..a])
  }
}

// "11" -> [0,0,0,0,0,0,1,1]
fn left_pad(s: String) -> List(Int) {
  string.split(s, "")
  |> list.map(fn(s) {
    case int.parse(s) {
      Ok(s) -> s
      _ -> 0
    }
  })
  |> pad
}

pub fn spell_check(path_to_bloom_filter: String, word: String) {
  let bf_handle = case file_stream.open_read(path_to_bloom_filter) {
    Ok(k) -> k
    Error(e) -> {
      let error_message = "Couldnt read file: " <> path_to_bloom_filter
      io.debug(e)
      panic as error_message
    }
  }

  let #(header, bytes) = read_filter(bf_handle)
  let hashes =
    get_hashes(word, header.bloom_filter_size, header.hash_fns_count, [])
  // slow, very bad ~ must optimize the datastrcuture
  let bit_list =
    bin_to_list(bytes, 0, bit_array.byte_size(bytes))
    |> list.map(fn(x) {
      integer_to_list(x, 2)
      |> left_pad
    })
    |> list.flatten
  let results =
    hashes
    |> list.map(fn(x) { nth(x, bit_list) })
    |> list.fold(0, fn(x, y) { x + y })

  case results {
    k if k + 1 == header.hash_fns_count -> True
    _ -> False
  }
}
