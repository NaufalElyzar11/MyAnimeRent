bool isCatalogImage(List<int> bytes) {
  bool starts(List<int> prefix) =>
      bytes.length > prefix.length &&
      List.generate(
        prefix.length,
        (i) => bytes[i] == prefix[i],
      ).every((v) => v);
  return starts([137, 80, 78, 71, 13, 10, 26, 10]) ||
      starts([255, 216, 255]) ||
      (starts([82, 73, 70, 70]) &&
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP');
}
