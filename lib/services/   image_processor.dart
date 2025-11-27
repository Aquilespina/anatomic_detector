import 'package:image/image.dart' as img;


class ImageProcessor {


  static img.Image resizeImage(
      img.Image image, {
        required int targetWidth,
        required int targetHeight,
        bool maintainAspect = true,
      }) {
    if (maintainAspect) {
      return img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        maintainAspect: true,
      );
    } else {
      return img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
      );
    }
  }


  static img.Image cropROI(
      img.Image image, {
        required int x,
        required int y,
        required int width,
        required int height,
      }) {
    return img.copyCrop(image, x, y, width, height);
  }


  static img.Image adjustContrast(img.Image image, double contrast) {
    return img.adjustColor(image, contrast: contrast);
  }

  /// Convertir a escala de grises
  static img.Image convertToGrayscale(img.Image image) {
    return img.grayscale(image);
  }

  /// Normalizar píxeles a rango [0, 1]
  static List<List<List<double>>> normalizePixels(img.Image image) {
    var normalized = List.generate(
      image.height,
          (y) => List.generate(
        image.width,
            (x) => List.generate(3, (channel) => 0.0),
      ),
    );

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        var pixel = image.getPixel(x, y);
        normalized[y][x][0] = img.getRed(pixel) / 255.0;
        normalized[y][x][1] = img.getGreen(pixel) / 255.0;
        normalized[y][x][2] = img.getBlue(pixel) / 255.0;
      }
    }

    return normalized;
  }
}