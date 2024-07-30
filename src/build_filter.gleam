import file_streams/file_stream
import file_streams/text_encoding
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import mumu

fn hash(text: String, max_bound: Int, i: Int) -> Int {
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

  io.println("Converting to String")
  let buffer_str =
    dict_to_list(buffer_dict, 0, filter_size)
    |> list.map(fn(x) {
      case dict.get(buffer_dict, x) {
        Ok(x) -> int.to_string(x)
        _ -> int.to_string(0)
      }
    })
    |> list.fold("", fn(b, a) { b <> a })
  io.println("Converting to String - Finish")

  io.println("Writing bloomfilter")
  let dest_handle = case
    file_stream.open_write_text(path_to_dict_output, encoding)
  {
    Ok(handle) -> handle
    Error(e) -> {
      let error_message = "Couldnt load file to write: " <> path_to_dict_output
      io.debug(e)
      panic as error_message
    }
  }
  let _ = case file_stream.write_chars(dest_handle, buffer_str) {
    Ok(handle) -> handle
    Error(e) -> {
      let error_message = "Couldnt write to dest. file: " <> path_to_dict_output
      io.debug(e)
      panic as error_message
    }
  }
  io.println("Writing bloomfilter - Finish" <> path_to_dict_output)
}
