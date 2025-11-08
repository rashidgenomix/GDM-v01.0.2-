List<Map<String, dynamic>> generateLayoutGrid({
  required String design,
  required List<String> accessions,
  required int replications,
  required int treatments,
  required int observations,
}) {
  final List<Map<String, dynamic>> grid = [];

  for (String accession in accessions) {
    switch (design.toUpperCase()) {
      case 'RCBD':
      case 'CRD':
        for (int rep = 1; rep <= replications; rep++) {
          for (int trt = 1; trt <= treatments; trt++) {
            for (int obs = 1; obs <= observations; obs++) {
              grid.add({
                'Accession': accession,
                'Rep': rep,
                'Trt': 'T\$trt',
                'Obs': obs,
              });
            }
          }
        }
        break;

      case 'FACTORIAL':
        for (int a = 1; a <= treatments; a++) {
          for (int b = 1; b <= treatments; b++) {
            for (int rep = 1; rep <= replications; rep++) {
              for (int obs = 1; obs <= observations; obs++) {
                grid.add({
                  'Accession': accession,
                  'Rep': rep,
                  'Trt': 'A\$a-B\$b',
                  'Obs': obs,
                });
              }
            }
          }
        }
        break;

      case 'AUGMENTED':
        for (int trt = 1; trt <= treatments; trt++) {
          for (int obs = 1; obs <= observations; obs++) {
            grid.add({
              'Accession': accession,
              'Rep': 1,
              'Trt': 'T\$trt',
              'Obs': obs,
            });
          }
        }
        break;

      default:
        throw Exception("Unsupported layout design: \$design");
    }
  }

  return grid;
}