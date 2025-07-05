class AnalysisProcessor {
  static String process(String analysis) {
    // Correções hierárquicas para garantir a qualidade do texto
    final correctionLayers = [
      // Camada 1: Correções de caracteres especiais e encoding
      {
        r'Ã©': 'é',
        r'â¬': '€',
        r'Ã¢': 'â',
        r'Ã ': 'à',
        r'Ã´': 'a',
        r'Ã³': 'ó',
        r'Ã£': 'ã',
        r'Ã§': 'ç',
        r'Ã¡': 'á',
        r'Ãª': 'ê',
        r'Ãµ': 'õ',
        r'Ãº': 'ú',
        r'Ã­': 'í',
        r'Â': '', // Remove caracteres Â incorretos
        r'\[270Ãive\]': '', // Remove códigos estranhos
      },
      // Camada 2: Correções gramaticais e de vocabulário
      {
        r'\bntimos\b': 'últimos',
        r'\breconendável\b': 'recomendável',
        r'\bpreão\b': 'preço',
        r'\bgerenciaç\b': 'gerenciar',
        r'\bmais agressiva\b': 'mais efetiva',
        r'\bA distribuição limitada\b': 'Distribuição limitada',
        r'\bÃºltimos\b': 'últimos',
        r'\Ãºnica\b': 'única',
        r'\bnÃ­veis\b': 'níveis',
        r'\bpossÃ­vel\b': 'possível',
        r'\bpromções\b': 'promoções',
        r'\bergonamico\b': 'orgânico',
        r'\bergonamica\b': 'orgânica',
      },
      // Camada 3: Melhoria de estrutura e clareza
      {
        r'\bpode estar contribuindo\b': 'contribui',
        r'\bnão há sazonalidade relevante identificada\b': 
          'não foi identificado padrão sazonal relevante',
        r'\bavaliar a possibilidade de\b': 'considerar',
        r'\bsugere-se aumentar\b': 'recomenda-se expandir',
      },
    ];

    // Aplica todas as camadas de correção
    for (var layer in correctionLayers) {
      layer.forEach((pattern, replacement) {
        analysis = analysis.replaceAll(RegExp(pattern, multiLine: true), replacement);
      });
    }

    // Pós-processamento final
    return analysis
        .replaceAll(RegExp(r'\s+\.'), '.')
        .replaceAll(RegExp(r'\s+,'), ',')
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
        .trim();
  }
}