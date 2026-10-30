# Remover metadados de imagens no Windows

O script `Remover-Metadados.ps1` usa o ExifTool para remover metadados editáveis sem reexportar ou recomprimir a imagem. Salva outra imagem com `-sem-metadados` no nome e mantém o original como cópia de segurança. Se o nome já existir, acrescenta um número.

## Preparação (uma vez)

1. Baixe o ExifTool para Windows no site oficial: https://exiftool.org/.
2. Extraia o pacote inteiro. Renomeie `exiftool(-k).exe` para `exiftool.exe`.
3. Coloque `exiftool.exe` e sua pasta `exiftool_files` junto de `Remover-Metadados.ps1`. A pasta de apoio deve continuar ao lado do executável.

Você também pode deixar o ExifTool em outro local e informar `-ExifToolPath "C:\Ferramentas\exiftool.exe"`. Se estiver no PATH, ele será encontrado automaticamente.

## Uma imagem

Abra o PowerShell na pasta do script e execute:

```powershell
.\Remover-Metadados.ps1 -Caminho "C:\Users\guilh\Downloads\imagem.png"
```

O resultado será `imagem-sem-metadados.png`, na mesma pasta da imagem original.

Se o Windows bloquear a execução do script, use esta chamada. Ela vale somente para esse processo e não altera a política permanente:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Remover-Metadados.ps1" -Caminho "C:\Fotos\foto.jpg"
```

## Várias imagens ou outra pasta de saída

```powershell
.\Remover-Metadados.ps1 -Caminho "C:\Fotos\a.jpg","C:\Fotos\b.png","C:\Fotos\c.webp"

.\Remover-Metadados.ps1 -Caminho "C:\Fotos\foto.jpg" -PastaSaida "C:\Fotos\Limpas"
```

Para uma pasta de JPGs, sem incluir subpastas:

```powershell
$imagens = @(Get-ChildItem -LiteralPath "C:\Fotos" -File -Filter "*.jpg" | Select-Object -ExpandProperty FullName)
if ($imagens.Count -gt 0) { .\Remover-Metadados.ps1 -Caminho $imagens }
```

## Cor e orientação

O comportamento padrão solicita a exclusão de todos os metadados removíveis (`-all=`). Isso inclui perfis de cor e informações de rotação, quando removíveis. Os dados comprimidos da imagem não são recomprimidos, mas a exibição pode mudar se o visualizador dependia dessas informações.

Para manter a aparência das fotos, preservando os metadados de cor e orientação:

```powershell
.\Remover-Metadados.ps1 -Caminho "C:\Fotos\foto.jpg" -PreservarAparencia
```

Esse modo mantém deliberadamente algumas informações de exibição; não significa ausência total de metadados.

## Formatos e verificação

- O script aceita JPEG/JPG, PNG (incluindo animação PNG), WebP, TIFF, GIF, HEIC, AVIF, JPEG XL, JPEG 2000, PSD, JNG e MNG. A escrita efetiva depende do suporte do ExifTool à variante do arquivo; qualquer erro é informado, e o original permanece intacto.
- Formatos RAW, PDFs e arquivos desconhecidos são recusados. Não existe um procedimento único que possa apagar indiscriminadamente todos os metadados de qualquer formato sem comprometer o arquivo.
- Compara largura e altura. Quando o ExifTool fornece `ImageDataHash`, também compara o hash SHA-256 dos dados da imagem antes e depois. Quando esse hash não está disponível, informa essa limitação explicitamente.
- A limpeza diz respeito aos metadados incorporados removíveis. Nome do arquivo, datas do sistema de arquivos e informações estruturais como dimensões e compressão continuam existindo.
- Para inspecionar a cópia limpa: `exiftool -a -G1 -s "C:\Fotos\foto-sem-metadados.jpg"`.
- O script não precisa de internet depois de o ExifTool estar disponível. Não faz upload das imagens.

## Validação desta entrega

Testado com PowerShell 7 e ExifTool 13.60 em cópias PNG, JPG, WebP, TIFF e GIF. A comparação dos pixels decodificados confirmou igualdade, incluindo o canal de transparência. Também foram testados: preservação dos originais, nomes já existentes, preservação opcional da orientação e recusa de um arquivo inválido. Os demais formatos listados dependem do suporte do ExifTool e não foram testados nesta entrega.

Fontes oficiais: https://exiftool.org/faq.html#Q32 e https://exiftool.org/exiftool_pod.html.
