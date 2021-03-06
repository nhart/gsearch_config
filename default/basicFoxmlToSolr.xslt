﻿<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
  xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
    		exclude-result-prefixes="exts"
  xmlns:zs="http://www.loc.gov/zing/srw/"
  xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
  xmlns:rel="info:fedora/fedora-system:def/relations-external#"
  xmlns:dwc="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
  xmlns:fedora-model="info:fedora/fedora-system:def/model#"
  xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
  xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
  xmlns:eaccpf="urn:isbn:1-931666-33-4"
  xmlns:res="http://www.w3.org/2001/sw/DataAccess/rf1/result"
  xmlns:xalan="http://xml.apache.org/xalan"
  xmlns:xlink="http://www.w3.org/1999/xlink">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <xsl:include href="file:/var/www/html/drupal/sites/all/modules/islandora_fjm/xsl/basicFJMToSolr.xslt"/>
  <xsl:include href="file:/var/www/html/drupal/sites/all/modules/islandora_fjm/xsl/escape_xml.xslt"/>
  <xsl:include href="file:/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/gsearch_solr/mods_to_solr_fields.xslt"/>

  <xsl:param name="REPOSITORYNAME" select="repositoryName"/>
  <xsl:param name="FEDORASOAP" select="repositoryName"/>
  <xsl:param name="FEDORAUSER" select="repositoryName"/>
  <xsl:param name="FEDORAPASS" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>

  <!-- Test of adding explicit parameters to indexing -->
  <xsl:param name="EXPLICITPARAM1" select="defaultvalue1"/>
  <xsl:param name="EXPLICITPARAM2" select="defaultvalue2"/>
<!--
	 This xslt stylesheet generates the IndexDocument consisting of IndexFields
     from a FOXML record. The IndexFields are:
       - from the root element = PID
       - from foxml:property   = type, state, contentModel, ...
       - from oai_dc:dc        = title, creator, ...
     The IndexDocument element gets a PID attribute, which is mandatory,
     while the PID IndexField is optional.
     Options for tailoring:
       - IndexField types, see Lucene javadoc for Field.Store, Field.Index, Field.TermVector
       - IndexField boosts, see Lucene documentation for explanation
       - IndexDocument boosts, see Lucene documentation for explanation
       - generation of IndexFields from other XML metadata streams than DC
         - e.g. as for uvalibdesc included above and called below, the XML is inline
         - for not inline XML, the datastream may be fetched with the document() function,
           see the example below (however, none of the demo objects can test this)
       - generation of IndexFields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
         - from datastream by sequence of mimetypes,
           text fetched from the first mimetype that can be handled,
           default sequence given in properties.
-->

  <xsl:template match="/">
    <xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
    <add>
      <!-- The following allows only active FedoraObjects to be indexed. -->
      <xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state']">
        <xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP' or @ID='DS-COMPOSITE-MODEL'])">
          <xsl:choose>
            <!-- avoid indexing stuff with their own cores -->
            <xsl:when test="starts-with($PID, 'atm')"/>
            <xsl:when test="starts-with($PID, 'jt')"/>
            <xsl:when test="starts-with($PID, 'ir')"/>
            <xsl:when test="starts-with($PID, 'cam')"/>
			<xsl:when test="starts-with($PID, 'ens')"/>
			<xsl:when test="starts-with($PID, 'cat')"/>
            <xsl:otherwise>
              <doc>
                <xsl:choose>
                  <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@VALUE='Active']">
                    <xsl:apply-templates select="/foxml:digitalObject" mode="activeFedoraObject">
                      <xsl:with-param name="PID" select="$PID"/>
                    </xsl:apply-templates>
                  </xsl:when>
                  <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@VALUE='Inactive']">
                    <xsl:apply-templates select="/foxml:digitalObject" mode="inactiveFedoraObject">
                      <xsl:with-param name="PID" select="$PID"/>
                    </xsl:apply-templates>
                  </xsl:when>
                  <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@VALUE='Deleted']">
                    <xsl:apply-templates select="/foxml:digitalObject" mode="deletedFedoraObject">
                      <xsl:with-param name="PID" select="$PID"/>
                    </xsl:apply-templates>
                  </xsl:when>
                  <xsl:otherwise>
                      <field name="PID"><xsl:value-of select="$PID"/></field>
                      <field name="error_s"><xsl:text>What kinda state is this!?</xsl:text></field>
                  </xsl:otherwise>
                </xsl:choose>
              </doc>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:if>
    </add>
  </xsl:template>
  
  <xsl:template match="/foxml:digitalObject" mode="add-turina-thumbnail">
    <xsl:param name="pid"/>
    
    <xsl:variable name="results_tf">
      <xsl:call-template name="perform_query">
        <xsl:with-param name="query">
PREFIX fre: &lt;info:fedora/fedora-system:def/relations-external#&gt;
PREFIX fm: &lt;info:fedora/fedora-system:def/model#&gt;
PREFIX fv: &lt;info:fedora/fedora-system:def/view#&gt;
PREFIX ip: &lt;info:islandora/islandora-system:def/pageinfo#&gt;
SELECT ?thumbnail ?thumbnail_obj
FROM &lt;#ri&gt;
WHERE {
  ?thumbnail_obj ip:isPageOf ?this ;
                 fm:state fm:Active ;
                 fv:disseminates ?thumbnail .
  ?thumbnail fv:disseminationType &lt;info:fedora/*/TN&gt; ;
       fm:state fm:Active .
  ?this fm:state fm:Active
  FILTER(sameTerm(?this, &lt;info:fedora/<xsl:value-of select="$pid"/>&gt;)) .
}
        </xsl:with-param>
        <xsl:with-param name='lang'>sparql</xsl:with-param>
      </xsl:call-template>
    </xsl:variable>
    
    <xsl:for-each select="xalan:nodeset($results_tf)/res:sparql/res:results/res:result[position() = 1]">
      <field name="turina_thumbnail_s">
        <xsl:value-of select="substring-after(res:thumbnail_obj/@uri, 'info:fedora/')"/>
      </field>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
    <xsl:param name="PID"/>

    <field name="PID" boost="2.5">
      <xsl:value-of select="$PID"/>
    </field>
    
    <xsl:apply-templates select="foxml:objectProperties/foxml:property"/>
	
	 <xsl:for-each select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name[not(@usage)]">
	  <field name="mods_related_ms">
        <xsl:value-of select="."/>
      </field>
    </xsl:for-each>
  
  <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:title">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
  
	

    <!-- index DC -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
      <xsl:with-param name="prefix">dc.</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>

    <xsl:for-each select="foxml:datastream[@ID='RIGHTSMETADATA']/foxml:datastreamVersion[last()]/foxml:xmlContent//access/human/person">
      <field>
        <xsl:attribute name="name">access.person</xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select="foxml:datastream[@ID='RIGHTSMETADATA']/foxml:datastreamVersion[last()]/foxml:xmlContent//access/human/group">
      <field>
        <xsl:attribute name="name">access.group</xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select="foxml:datastream[@ID='TAGS']/foxml:datastreamVersion[last()]/foxml:xmlContent//tag">
          <!--<xsl:for-each select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent//tag">-->
      <field>
        <xsl:attribute name="name">tag</xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
      <field>
        <xsl:attribute name="name">tagUser</xsl:attribute>
        <xsl:value-of select="@creator"/>
      </field>
    </xsl:for-each>

    <!-- Index the Rels-ext (using match="rdf:RDF") -->
    <xsl:apply-templates select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF">
      <xsl:with-param name="prefix">rels_</xsl:with-param>
      <xsl:with-param name="suffix">_ms</xsl:with-param>
    </xsl:apply-templates>

    <!-- OCR -->
    <xsl:for-each select="foxml:datastream[@ID='OCR']/foxml:datastreamVersion[last()]">
      <field>
        <xsl:attribute name="name">ocr</xsl:attribute>
      <xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
            <xsl:message><xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/></xsl:message>
           <!-- <xsl:value-of select="islandora-exts:getDatastreamTextRaw($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/> -->
     	</field>
    </xsl:for-each>

      <!--********************************************Darwin Core**********************************************************************-->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/dwc:SimpleDarwinRecordSet/dwc:SimpleDarwinRecord/*[normalize-space(text())]">
      <xsl:with-param name="prefix">dwc.</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
      <!--***************************************** END Darwin Core ******************************************-->

      <!--************************************ BLAST ******************************************-->
      <!-- Blast -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='BLAST']/foxml:datastreamVersion[last()]/foxml:xmlContent//Hit/Hit_hsps/Hsp/*[normalize-space(text())]">
      <xsl:with-param name="prefix">blast.</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
      <!--********************************** End BLAST ******************************************-->

      <!-- Names and Roles -->
    <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="default"/>
    <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="turina"/>
    
    <!-- store an escaped copy of MODS... -->
    <xsl:if test="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods">
      <field name="mods_fullxml_store">
        <xsl:apply-templates select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods" mode="escape"/>
      </field>
    </xsl:if>

    <xsl:apply-templates select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf">
      <xsl:with-param name="pid" select="$PID"/>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="fjm" select="foxml:datastream[@ID='EAC-CPF']/foxml:datastreamVersion[last()]/foxml:xmlContent//eaccpf:eac-cpf">
      <xsl:with-param name="pid" select="$PID"/>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:for-each select="foxml:datastream[@ID][foxml:datastreamVersion[last()]]">
	
        <xsl:choose>
          <!-- Don't bother showing some... -->
          <xsl:when test="@ID='AUDIT'"></xsl:when>
          <xsl:when test="@ID='DC'"></xsl:when>
          <xsl:when test="@ID='ENDNOTE'"></xsl:when>
          <xsl:when test="@ID='MODS'"></xsl:when>
          <xsl:when test="@ID='RIS'"></xsl:when>
          <xsl:when test="@ID='SWF'"></xsl:when>
          <xsl:otherwise>
            <field name="fedora_datastreams_ms">
              <xsl:value-of select="@ID"/>
            </field>
          </xsl:otherwise>
        </xsl:choose>
    </xsl:for-each>
  
  
  
  </xsl:template>

  <xsl:template match="/foxml:digitalObject" mode="inactiveFedoraObject">
    <xsl:param name="PID"/>
    
    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    <xsl:apply-templates select="foxml:property"/>
  </xsl:template>
  
  <xsl:template match="/foxml:digitalObject" mode="deletedFedoraObject">
    <xsl:param name="PID"/>

    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    <xsl:apply-templates select="foxml:property"/>
  </xsl:template>
  
  <xsl:template match="foxml:property">
    <xsl:param name="prefix">ffs_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>
    <xsl:param name="date_suffix">_dt</xsl:param>
    
    <xsl:variable name="name" select="substring-after(@NAME,'#')"/>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, $name, $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="@VALUE"/>
    </field>
    
    <xsl:if test="$name='lastModifiedDate' or $name='createdDate'">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, $name, $date_suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@VALUE"/>
      </field>
    </xsl:if>
  </xsl:template>
    
  <xsl:template match="mods:mods" mode="turina">
    <field name="turina_type_s">
      <xsl:choose>
        <xsl:when test="starts-with(normalize-space(mods:location/mods:shelfLocation/text()), 'LJT-P-')">Partitura</xsl:when>
        <xsl:when test="starts-with(normalize-space(mods:location/mods:shelfLocation/text()), 'LJT-Pre-')">Prensa</xsl:when>
        <xsl:when test="starts-with(normalize-space(mods:location/mods:shelfLocation/text()), 'LJT-M')">Manuscrito</xsl:when>
        <xsl:when test="starts-with(normalize-space(mods:location/mods:shelfLocation/text()), 'LJT-Cor')">Correspondencia</xsl:when>
        <xsl:when test="starts-with(normalize-space(mods:genre[@authority='Joaquín_Turina']/text()), 'Programa')">Programa de Mano</xsl:when>
        <xsl:when test="starts-with(normalize-space(mods:genre[@authority='Joaquín_Turina']/text()), 'Tarjeta Postal') or 
          starts-with(normalize-space(mods:genre[@authority='Joaquín_Turina']/text()), 'Fotografîa')">Archivo Fotográfico</xsl:when>
        <xsl:when test="starts-with(normalize-space(mods:genre[@authority='ingest']/text()), 'Diarios')">Diario</xsl:when>
        <xsl:otherwise>Unknown types</xsl:otherwise>
      </xsl:choose>
    </field>
  </xsl:template>
  
  <xsl:template match="rdf:RDF">
    <xsl:param name="prefix">rels_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>

    <xsl:for-each select=".//rdf:Description/*[@rdf:resource]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_uri', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@rdf:resource"/>
      </field>
    </xsl:for-each>
    <xsl:for-each select=".//rdf:Description/*[not(@rdf:resource)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_literal', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>

  <!-- Basic EAC-CPF -->
  <xsl:template match="eaccpf:eac-cpf">
        <xsl:param name="pid"/>
        <xsl:param name="dsid" select="'EAC-CPF'"/>
        <xsl:param name="prefix" select="'eaccpf_'"/>
        <xsl:param name="suffix" select="'_et'"/> <!-- 'edged' (edge n-gram) text, for auto-completion -->

        <xsl:variable name="cpfDesc" select="eaccpf:cpfDescription"/>
        <xsl:variable name="identity" select="$cpfDesc/eaccpf:identity"/>
        <xsl:variable name="name_prefix" select="concat($prefix, 'name_')"/>
        <!-- ensure that the primary is first -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[@localType='primary']">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>

        <!-- place alternates (non-primaries) later -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[not(@localType='primary')]">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>
    </xsl:template>

  <xsl:template match="eaccpf:nameEntry">
    <xsl:param name="pid"/>
    <xsl:param name="prefix">eaccpf_name_</xsl:param>
    <xsl:param name="suffix">_et</xsl:param>

    <!-- fore/first name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'given', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="part[@localType='middle']">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(eaccpf:part[@localType='forename'])"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>
    
    <!-- sur/last name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'family', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(eaccpf:part[@localType='surname'])"/>
    </field>
    
    <!-- id -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'id', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:value-of select="concat($pid, '/', @id)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($pid,'/name_position:', position())"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>

    <!-- full/complete name -->
    <xsl:variable name="full_name">
      <xsl:choose>
        <xsl:when test="normalize-space(part[@localType='middle'])">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename']))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'complete', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="$full_name"/>
    </field>
    
    <!-- create sortable copy -->
    <xsl:if test="@localType='primary'">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'complete', '_es')"/>
        </xsl:attribute>
        <xsl:value-of select="$full_name"/>
      </field>
    </xsl:if>
  </xsl:template>

  <xsl:template match="eaccpf:eac-cpf" mode="fjm">
    <xsl:param name="pid"/>
    <xsl:param name="prefix">eaccpf_</xsl:param>
    <xsl:param name="suffix">_et</xsl:param>
    
    <xsl:variable name="TN_TF">
      <xsl:call-template name="perform_query">
        <xsl:with-param name="lang">sparql</xsl:with-param>
        <xsl:with-param name="query">
PREFIX ir-rel: &lt;http://digital.march.es/ceacs#&gt;
SELECT $tn_pid
WHERE {
  $tn_pid ir-rel:iconOf &lt;info:fedora/<xsl:value-of select="$pid"/>&gt;
}
        </xsl:with-param>
      </xsl:call-template>
    </xsl:variable>
    <xsl:for-each select="xalan:nodeset($TN_TF)/res:sparql/res:results/res:result[1]/res:tn_pid">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'thumbnail_object', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="substring-after(@uri, '/')"/>
      </field>
    </xsl:for-each>
    
    <xsl:for-each select='(eaccpf:cpfDescription/eaccpf:relations/eaccpf:resourceRelation[eaccpf:descriptiveNote/eaccpf:p/text()="Academic page"])[1]'>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'academic_page', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@xlink:href"/>
      </field>
    </xsl:for-each>
    
    <xsl:for-each select='(eaccpf:cpfDescription/eaccpf:relations/eaccpf:cpfRelation[starts-with(eaccpf:relationEntry/text(), "Institute Juan March")])[1]'>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'ceacs_member', '_b')"/>
        </xsl:attribute>
        <xsl:text>true</xsl:text>
      </field>
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'ceacs_role', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="normalize-space(eaccpf:relationEntry/text())"/>
        
        <xsl:variable name="dateInfo">
          <xsl:choose>
            <xsl:when test="substring(eaccpf:relationEntry/text(), string-length(eaccpf:relationEntry/text()) - 3, 'PhD')">
              <xsl:value-of select="../../eaccpf:description/eaccpf:biogHist/eaccpf:chronList/eaccpf:chronItem[eaccpf:event/text()='Achieved PhD']/eaccpf:date/@standardDate"/>
            </xsl:when>
            <xsl:when test="eaccpf:dateRange">
              <xsl:if test="eaccpf:dateRange/eaccpf:fromDate">
                <xsl:value-of select="eaccpf:dateRange/eaccpf:fromDate/text()"/>
              </xsl:if>
              <xsl:text>-</xsl:text>
              <xsl:if test="eaccpf:dateRange/eaccpf:toDate">
                <xsl:value-of select="eaccpf:dateRange/eaccpf:toDate/text()"/>
              </xsl:if>
            </xsl:when>
          </xsl:choose>
        </xsl:variable>
        
        <xsl:if test="not($dateInfo='')">
          <xsl:text> (</xsl:text>
          <xsl:value-of select="$dateInfo"/>
          <xsl:text>)</xsl:text>
        </xsl:if>
      </field>
    </xsl:for-each>
  </xsl:template>
  
  <!-- Create fields for the set of selected elements, named according to the 'local-name' and containing the 'text' -->
  <xsl:template match="*" mode="simple_set">
    <xsl:param name="prefix">changeme_</xsl:param>
    <xsl:param name="suffix">_t</xsl:param>

    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="text()"/>
    </field>
  </xsl:template>
</xsl:stylesheet>
