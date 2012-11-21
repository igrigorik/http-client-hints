<!--
    XSLT transformation from RFC2629 XML format to Microsoft HTML Help Keyword (Index) File

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

<xsl:include href="rfc2629.xslt" />

<xsl:template match="/" priority="9">
<html>
  <head>
    <meta name="generator" content="rfc2629toHhk.xslt $Id: rfc2629toHhk.xslt,v 1.6 2003-11-16 14:52:40 jre Exp $" />
  </head>
  <body>
    <ul>
      <xsl:for-each select="//iref">
        <xsl:sort select="@item" />
        <xsl:if test="generate-id(.) = generate-id(key('index-item',@item))">
          <li>
            <xsl:variable name="num"><xsl:number level="any" /></xsl:variable>
            <object type="text/sitemap">
              <param name="Keyword" value="{@item}" />
              <xsl:for-each select="key('index-item',@item)[not(@subitem) or @subitem='']">
                <xsl:variable name="sec"><xsl:call-template name="get-section-number" /></xsl:variable>
                <param name="Name" value="{$sec} {ancestor::section[1]/@title}" />
                <param name="Local" value="{$basename}.html#rfc.section.{$sec}" />
              </xsl:for-each>
              <xsl:if test="key('index-item',@item)[@subitem!='']">
                <param name="See Also" value="{@item}" />
              </xsl:if>
            </object>
            <xsl:if test="key('index-item',@item)[@subitem!='']">
              <ul>
                <xsl:for-each select="key('index-item',@item)[@subitem!='']">
                  <li>
                    <object type="text/sitemap">
                      <param name="Keyword" value="{@subitem}" />
                      <xsl:variable name="sec"><xsl:call-template name="get-section-number" /></xsl:variable>
                      <param name="Name" value="{$sec} {ancestor::section[1]/@title}" />
                      <param name="Local" value="{$basename}.html#rfc.section.{$sec}" />
                    </object>
                  </li>
                </xsl:for-each>
              </ul>
            </xsl:if>
          </li>
        </xsl:if>
      </xsl:for-each>
    </ul>
  </body>
</html>
</xsl:template>

</xsl:transform>