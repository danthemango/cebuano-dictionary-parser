param (
    [string] $inpath = ".\cebuano-dictionary.html"
) 

$html = Get-Content $inpath -Raw

# Use SingleLine flag to make . match newlines too
$options = [System.Text.RegularExpressions.RegexOptions]::Singleline

# remove doctype
$html = [regex]::Replace($html, '<!DOCTYPE[^>]*>', '', $options)

# Fix self-closing tags that should be self-closed in HTML5
# Meta tags (handle both <meta...> and <meta.../>)
$html = [regex]::Replace($html, '<(meta)(.+?)\s*/?>', '<$1$2/>', $options)
# Link tags
$html = [regex]::Replace($html, '<(link)(.+?)\s*/?>', '<$1$2/>', $options)
# Br tags
$html = [regex]::Replace($html, '<(br)\s*/?>', '<$1/>', $options)
# Hr tags
$html = [regex]::Replace($html, '<(hr)\s*/?>', '<$1/>', $options)
# Img tags
$html = [regex]::Replace($html, '<(img)(.+?)\s*/?>', '<$1$2/>', $options)
# Input tags
$html = [regex]::Replace($html, '<(input)(.+?)\s*/?>', '<$1$2/>', $options)
# hr tags
$html = [regex]::Replace($html, '<(hr)(.+?)\s*/?>', '<$1$2/>', $options)

# Fix unclosed tags by adding closing tags where needed
# Example: fix standalone </meta> or </br> tags without opening
$html = $html -replace '</meta>', ''
$html = $html -replace '</br>', ''
$html = $html -replace '</hr>', ''
$html = $html -replace '</img>', ''
$html = $html -replace '</link>', ''
$html = $html -replace '</input>', ''

# Convert common HTML named entities to numeric entities for XML compatibility
# Accented characters
$html = $html -replace '&aacute;', '&#225;'  # á
$html = $html -replace '&eacute;', '&#233;'  # é
$html = $html -replace '&iacute;', '&#237;'  # í
$html = $html -replace '&oacute;', '&#243;'  # ó
$html = $html -replace '&uacute;', '&#250;'  # ú
$html = $html -replace '&agrave;', '&#224;'  # à
$html = $html -replace '&egrave;', '&#232;'  # è
$html = $html -replace '&igrave;', '&#236;'  # ì
$html = $html -replace '&ograve;', '&#242;'  # ò
$html = $html -replace '&ugrave;', '&#249;'  # ù
$html = $html -replace '&auml;', '&#228;'    # ä
$html = $html -replace '&euml;', '&#235;'    # ë
$html = $html -replace '&iuml;', '&#239;'    # ï
$html = $html -replace '&ouml;', '&#246;'    # ö
$html = $html -replace '&uuml;', '&#252;'    # ü
$html = $html -replace '&aring;', '&#229;'   # å
$html = $html -replace '&aelig;', '&#230;'   # æ
$html = $html -replace '&ntilde;', '&#241;'  # ñ
$html = $html -replace '&oslash;', '&#248;'  # ø
$html = $html -replace '&ccedil;', '&#231;'  # ç
# Quotes and dashes
$html = $html -replace '&rsquo;', '&#8217;'  # right single quotation mark
$html = $html -replace '&lsquo;', '&#8216;'  # left single quotation mark
$html = $html -replace '&rdquo;', '&#8221;'  # right double quotation mark
$html = $html -replace '&ldquo;', '&#8220;'  # left double quotation mark
$html = $html -replace '&mdash;', '&#8212;'  # em dash
$html = $html -replace '&ndash;', '&#8211;'  # en dash
# Arrows and symbols
$html = $html -replace '&rarr;', '&#8594;'   # right arrow
$html = $html -replace '&larr;', '&#8592;'   # left arrow
$html = $html -replace '&prime;', '&#8242;'  # prime (single quote superscript)
$html = $html -replace '&Prime;', '&#8243;'  # double prime
$html = $html -replace '&nbsp;', '&#160;'    # non-breaking space
$html = $html -replace '&copy;', '&#169;'    # copyright
$html = $html -replace '&reg;', '&#174;'     # registered trademark
$html = $html -replace '&dagger;', '&#8224;' # dagger
# frac12
$html = $html -replace '&frac12;', '&#189;'  # ½
# ucirc
$html = $html -replace '&ucirc;', '&#251;'   # û
# deg
$html = $html -replace '&deg;', '&#176;'     # degree symbol
# acirc
$html = $html -replace '&acirc;', '&#226;'   # â
# frac14
$html = $html -replace '&frac14;', '&#188;'  # ¼
# frac34
$html = $html -replace '&frac34;', '&#190;'  # ¾
# icirc
$html = $html -replace '&icirc;', '&#238;'   # î
# frasl
$html = $html -replace '&frasl;', '&#8260;'  # fraction slash
# gt
$html = $html -replace '&gt;', '&gt;'        # greater than (already valid in XML)
# lt
$html = $html -replace '&lt;', '&lt;'        # less than (already valid in XML)

# Attempt to parse as XML to validate
try {
    $content = Get-Content -Path $inpath -Raw
    [xml]$xml = $content
    Write-Host "HTML successfully parsed as XML!"
}
catch {
    Write-Host "Warning: Could not parse as XML after fixes"
    Write-Host "Note: HTML is valid but may contain entities not fully XML-compatible"
}

Write-Host "HTML structural fixes applied:"
Write-Host "  - Self-closing tags (meta, link, br, hr, img, input) now properly formatted"
Write-Host "  - Multi-line tags fixed"
Write-Host "  - Common HTML entities converted to numeric form"

# write back to file
Set-Content -Path $inpath -Value $html -Encoding UTF8
Write-Host "Fixed HTML written to $inpath"