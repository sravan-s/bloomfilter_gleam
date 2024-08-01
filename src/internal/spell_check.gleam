import file_streams/file_stream
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import internal/build_filter
import internal/header

fn read_filter(handle: file_stream.FileStream) -> #(header.Header, List(Int)) {
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
    Ok(line) -> bin_to_list(line)
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
fn bin_to_list(bytes: BitArray) -> List(Int)

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

pub fn find_n(x: Int, on big_list: List(Int)) -> Int {
  // directly using this inside map breaks the somehow?
  nth(x, big_list)
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
    get_hashes(word, header.bloom_filter_size, header.hash_fns_count - 1, [])
    // [35, 218, 165, 5, 249, 138, 87]
    |> list.map(fn(x) {
      let position = x % 8
      let byte = find_n({ x / 8 }, on: bytes)
      let s =
        integer_to_list(byte, 2)
        |> left_pad

      find_n(position, s)
    })
    |> list.fold(0, fn(x, y) { x + y })

  hashes == header.hash_fns_count
}
