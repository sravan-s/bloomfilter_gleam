import file_streams/file_stream
import file_streams/text_encoding
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import internal/header
import mumu

pub fn hash(text: String, max_bound: Int, i: Int) -> Int {
  case mumu.hash_with_seed(text, i) {
    h if h > max_bound -> h % max_bound
    h if h <= max_bound -> h
    _ -> 0
  }
}

fn hash_iter(
  text: String,
  max_bound: Int,
  times: Int,
  buffer_dict: Dict(Int, Int),
) -> Dict(Int, Int) {
  let hashed = hash(text, max_bound, times)
  let buffer_dict = dict.insert(buffer_dict, hashed, 1)
  case times {
    t if t == 0 -> buffer_dict
    _ -> hash_iter(text, max_bound, times - 1, buffer_dict)
  }
}

fn encode(
  handle: file_stream.FileStream,
  filter_size: Int,
  hash_fns_count: Int,
  buffer_dict: Dict(Int, Int),
) -> Dict(Int, Int) {
  case file_stream.read_line(handle) {
    Ok(line) -> {
      let buffer_dict =
        hash_iter(line, filter_size, hash_fns_count, buffer_dict)
      encode(handle, filter_size, hash_fns_count, buffer_dict)
    }
    _ -> buffer_dict
  }
}

fn dict_to_list(d: Dict(Int, Int), current: Int, list_size: Int) -> List(Int) {
  let current_value = case dict.get(d, current) {
    Ok(c) -> c
    _ -> 0
  }
  case current {
    c if c > list_size -> []
    _ -> list.append([current_value], dict_to_list(d, current + 1, list_size))
  }
}

fn bit_list_to_bytes(l: List(Int)) -> Int {
  let size = list.length(l) - 1
  case l {
    [] -> 0
    [a] -> a
    [a, ..rest] -> { header.pow(2, size) * a } + bit_list_to_bytes(rest)
  }
}

pub fn right_padding(a: List(Int)) -> List(Int) {
  let size = list.length(a)
  case size {
    s if s < 8 -> {
      let padded = list.reverse([0, ..list.reverse(a)])
      right_padding(padded)
    }
    _ -> a
  }
}

pub fn list_to_bitarray(list: List(Int)) -> BitArray {
  case list {
    [] -> <<>>
    [a, b, c, d, e, f, g, h, ..rest] -> {
      let val = <<bit_list_to_bytes([a, b, c, d, e, f, g, h]):size(8)>>
      bit_array.append(val, list_to_bitarray(rest))
    }
    partial_bits -> <<bit_list_to_bytes(right_padding(partial_bits)):size(8)>>
  }
}

pub fn build_bloomfilter(
  path_to_dict_src: String,
  path_to_dict_output: String,
  filter_size: String,
  hash_fns_count: String,
) {
  io.println("Building boomfilter")
  // validate
  let filter_size: Int = case int.parse(filter_size) {
    Ok(size) -> size
    _ -> panic as { "Couldnt parse filter_size(m): " <> filter_size }
  }
  // maybe add upper/lower bound to size and count

  let hash_fns_count: Int = case int.parse(hash_fns_count) {
    Ok(count) -> count
    _ -> panic as { "Couldnt parse filter_size(m): " <> hash_fns_count }
  }
  // end-validate

  let encoding = text_encoding.Latin1
  let src_handle = case file_stream.open_read_text(path_to_dict_src, encoding) {
    Ok(handle) -> handle
    Error(e) -> {
      let error_message = "Couldnt load file: " <> path_to_dict_src
      io.debug(e)
      panic as error_message
    }
  }

  io.println("Reading lines")
  let buffer_dict = dict.new()
  let buffer_dict = encode(src_handle, filter_size, hash_fns_count, buffer_dict)
  io.println("Reading lines - Finish")

  // lol, performance here is super bad
  io.println("Converting to BitArray")
  let filter_data =
    dict_to_list(buffer_dict, 0, filter_size)
    |> list_to_bitarray
  let header_info =
    header.encode_header(header.Header(
      bloom_filter_size: filter_size,
      hash_fns_count: hash_fns_count,
      version: header.version,
    ))
  let data = bit_array.append(header_info, filter_data)
  io.println("Converting to BitArray - Finish")

  io.println("Writing bloomfilter")
  let dest_handle = case file_stream.open_write(path_to_dict_output) {
    Ok(handle) -> handle
    Error(e) -> {
      let error_message = "Couldnt load file to write: " <> path_to_dict_output
      io.debug(e)
      panic as error_message
    }
  }
  let _ = case file_stream.write_bytes(dest_handle, data) {
    Ok(handle) -> handle
    Error(e) -> {
      let error_message = "Couldnt write to dest. file: " <> path_to_dict_output
      io.debug(e)
      panic as error_message
    }
  }
  io.println("Writing bloomfilter - Finish" <> path_to_dict_output)
}
