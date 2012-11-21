<!--
    XSLT transformation from RFC2629 XML format to Microsoft HTML Help Project File

    Copyright (c) 2003 Julian F. Reschke (julian.reschke@greenbytes.de)

    placed into the public domain

    change history:

    2003-11-16  julian.reschke@greenbytes.de

    Initial release.
-->

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
>

<xsl:param name="basename" />

<xsl:output method="text" />

<xsl:template match="/">
[OPTIONS]
Compiled File=<xsl:value-of select="$basename" />.chm
Contents File=<xsl:value-of select="$basename" />.hhc
<xsl:if test="//iref">
Index File=<xsl:value-of select="$basename" />.hhk
</xsl:if>
Binary TOC=Yes
Compatibility=1.1 or later
Display compile progress=No
Full-text search=Yes
Language=0x409
Title=<xsl:value-of select="/rfc/front/title" />

[FILES]
<xsl:value-of select="$basename" />.html
&#10;
</xsl:template>

</xsl:transform>