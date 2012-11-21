<!--
    Produce a reference entry based on an Amazon ASIN (ISBN) entry.

    Copyright (c) 2006, Julian Reschke (julian.reschke@greenbytes.de)
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of Julian Reschke nor the names of its contributors
      may be used to endorse or promote products derived from this software
      without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
-->

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0"
>

<xsl:output indent="yes"/>

<xsl:param name="asin" />

<xsl:template match="/">
  <xsl:variable name="uri" select="concat('http://xml.amazon.com/onca/xml3?t=webservices-20&amp;dev-t=foobar&amp;AsinSearch=',$asin,'&amp;type=heavy&amp;f=xml')" />
  <xsl:variable name="res" select="document($uri)" />
  <references>
    <xsl:apply-templates select="$res/ProductInfo/Details" />
  </references>
</xsl:template>

<xsl:template name="initials">
  <xsl:param name="str"/>
  <xsl:choose>
    <xsl:when test="contains($str,' ')">
      <xsl:call-template name="initials">
        <xsl:with-param name="str">
          <xsl:value-of select="substring-before($str,' ')"/>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="initials">
        <xsl:with-param name="str">
          <xsl:value-of select="substring-after($str,' ')"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="substring($str,1,1)"/>. </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="get-surname">
  <xsl:param name="str"/>
  <xsl:choose>
    <xsl:when test="contains($str,' ')">
      <xsl:call-template name="get-surname">
        <xsl:with-param name="str" select="substring-after($str,' ')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$str"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="Author">
  <xsl:variable name="surname">
    <xsl:call-template name="get-surname">
      <xsl:with-param name="str" select="normalize-space(.)"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="givenname">
    <xsl:value-of select="normalize-space(substring-before(.,$surname))"/>
  </xsl:variable>
  <author surname="{$surname}" fullname="{$givenname} {$surname}">
    <xsl:attribute name="initials">
      <xsl:call-template name="initials">
        <xsl:with-param name="str" select="$givenname"/>
      </xsl:call-template>
    </xsl:attribute>
    <organization/>
  </author>
</xsl:template>

<xsl:template match="Details">
  <reference target="urn:isbn:{Isbn}">
    <front>
      <xsl:apply-templates select="ProductName"/>
      <xsl:apply-templates select="Authors/Author"/>
      <xsl:apply-templates select="ReleaseDate"/>
    </front>
    <xsl:apply-templates select="Manufacturer"/>
  </reference>
</xsl:template>

<xsl:template match="ReleaseDate">
  <xsl:variable name="part1" select="normalize-space(substring-before(.,','))" />
  <xsl:variable name="part2" select="normalize-space(substring-after(.,','))" />
  <date year="{$part2}">
    <xsl:choose>
      <xsl:when test="contains($part1,' ')">
        <xsl:attribute name="month">
          <xsl:value-of select="substring-after($part1,' ')" />
        </xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="month">
          <xsl:value-of select="$part1" />
        </xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </date>
</xsl:template>

<xsl:template match="ProductName">
  <title><xsl:value-of select="."/></title>
</xsl:template>

<xsl:template match="Manufacturer">
  <seriesInfo name="{.}" value="" />
</xsl:template>



</xsl:transform>