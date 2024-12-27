String unescape(String input) {
  final sb = StringBuffer();
  int i = 0;

  while (i < input.length) {
    if (input[i] != '\\') {
      sb.write(input[i]);
      i++;
      continue;
    }

    i++;
    if (i >= input.length) {
      break;
    }

    switch (input[i]) {
      case '\\':
        sb.write('\\');
        break;
      case 't':
        sb.write('\t');
        break;
      case 'r':
        sb.write('\r');
        break;
      case 'n':
        sb.write('\n');
        break;
      case 'f':
        sb.write('\f');
        break;
      case 'b':
        sb.write('\b');
        break;
      case 'v':
        sb.write('\v');
        break;
      case 'u':
        if (i + 4 >= input.length) {
          break;
        }
        if (input[i + 1] == '{') {
          final match = RegExp(r"{([a-fA-F0-9]+)}").firstMatch(input.substring(i + 1));
          if (match == null) {
            break;
          }
          final hex = match.group(1)!;
          final code = int.parse(hex, radix: 16);
          sb.writeCharCode(code);
          i += match.end + 1;
        } else {
          final hex = input.substring(i + 1, i + 5);
          final code = int.parse(hex, radix: 16);
          sb.writeCharCode(code);
          i += 4;
        }
        break;
      case 'x':
        if (i + 2 >= input.length) {
          break;
        }
        final hex = input.substring(i + 1, i + 3);
        final code = int.parse(hex, radix: 16);
        sb.writeCharCode(code);
        i += 2;
        break;
      default:
        sb.write(input[i]);
    }
    i++;
  }

  return sb.toString();
}