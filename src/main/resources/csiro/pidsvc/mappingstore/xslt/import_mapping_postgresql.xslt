<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xpath-default-namespace="urn:csiro:xmlns:pidsvc:backup:1.0">
	<xsl:output method="text" version="1.0" encoding="UTF-8"/>
	<xsl:param name="AuthorizationName"/>

	<xsl:template match="/">
		<xsl:choose>
			<xsl:when test="mapping">
				<!-- Single mapping import -->
				<xsl:value-of select='concat("--OK: Successfully imported [mapping[[", mapping/path, "]]].")'/>
				BEGIN;
				<xsl:apply-templates select="mapping"/>
				COMMIT;
			</xsl:when>
			<xsl:when test="backup[@type = 'partial' and @scope = 'record']">
				<!-- Partial mapping import -->
				<xsl:value-of select='concat("--OK: Successfully imported [mapping[[", backup/mapping[1]/path, "]]].")'/>
				BEGIN;
				<xsl:apply-templates select="backup/mapping[1]"/>
				COMMIT;
			</xsl:when>
			<xsl:when test="backup[@type = 'full' and @scope = 'record']">
				<!-- Full mapping import -->
				<xsl:variable name="_path" select="backup/mapping[1]/path/text()"/>
				<xsl:variable name="path" select='replace(replace($_path, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
				<xsl:value-of select='concat("--OK: Successfully imported [mapping[[", $_path, "]]].")'/>
				BEGIN;
				<xsl:choose>
					<xsl:when test="$path = ''">
						<!-- Catch-all mapping -->
						DELETE FROM mapping WHERE mapping_path IS NULL;
						<xsl:apply-templates select="backup/mapping[not(path/text())]"/>
					</xsl:when>
					<xsl:otherwise>
						<!-- Regular mapping -->
						DELETE FROM mapping WHERE mapping_path = E'<xsl:value-of select="$path"/>';
						<xsl:apply-templates select="backup/mapping[path/text() = $_path]"/>
					</xsl:otherwise>
				</xsl:choose>
				COMMIT;
			</xsl:when>
			<xsl:when test="backup[@scope = 'db' or (not(@type) and not(@scope))]">
				<!-- Full/Partial db restore -->
				<xsl:value-of select="concat('--OK: Successfully imported ', count(distinct-values(/backup/mapping/path/text())), ' mapping(s).')"/>
				BEGIN;
				<xsl:call-template name="cleanup"/>
				<xsl:apply-templates select="backup/mapping"/>
				COMMIT;
			</xsl:when>
			<xsl:otherwise>--OK: No mapping rules found in the backup.</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="cleanup">
		<xsl:for-each select="distinct-values(/backup/mapping/path/text())">
			DELETE FROM mapping WHERE mapping_path = E'<xsl:value-of select='replace(replace(., "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>';
		</xsl:for-each>
	</xsl:template>
	<xsl:template match="mapping">
		<xsl:variable name="_path">
			<xsl:value-of select='replace(replace(path, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
		</xsl:variable>
		<xsl:variable name="path">
			<xsl:choose>
				<xsl:when test="path and $_path = ''">NULL</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="concat('E''', $_path, '''')"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="path_operand">
			<xsl:choose>
				<xsl:when test="$path = 'NULL'">IS NULL</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="concat(' = ', $path)"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="path_rename">
			<xsl:if test="path/@rename and $_path != ''">
				<xsl:text>E'</xsl:text>
				<xsl:value-of select='replace(replace(path/@rename, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
				<xsl:text>'</xsl:text>
			</xsl:if>
		</xsl:variable>
		<xsl:variable name="parent">
			<xsl:choose>
				<xsl:when test="parent and $_path != ''">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(parent, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="title">
			<xsl:choose>
				<xsl:when test="title and $_path != ''">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(title, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="type">
			<xsl:choose>
				<xsl:when test="$_path = ''">Regex</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="type"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="description">
			<xsl:choose>
				<xsl:when test="description">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(description, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="creator">
			<xsl:choose>
				<xsl:when test="$AuthorizationName">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace($AuthorizationName, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:when test="creator">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(creator, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="commit_note">
			<xsl:choose>
				<xsl:when test="commitNote">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(commitNote, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="default_action_id">
			<xsl:choose>
				<xsl:when test="action">
					<xsl:text>(SELECT currval('"action_action_id_seq"'::regclass))</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="default_action_description">
			<xsl:choose>
				<xsl:when test="action/description">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(action/description, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		<xsl:if test="/mapping and path/@rename and $_path != ''">
			DELETE FROM mapping WHERE mapping_path <xsl:value-of select="$path_operand"/>;
			UPDATE mapping SET mapping_path <xsl:value-of select="$path_operand"/> WHERE mapping_path = <xsl:value-of select="$path_rename"/>;
			UPDATE mapping SET parent <xsl:value-of select="$path_operand"/> WHERE parent = <xsl:value-of select="$path_rename"/>;
		</xsl:if>
		UPDATE mapping SET date_end = now() WHERE mapping_path <xsl:value-of select="$path_operand"/> AND date_end IS NULL;

		<xsl:apply-templates select="action" mode="default_action"/>

		<xsl:choose>
			<xsl:when test="/backup">
				<!-- Allow original_path/date_start/date_end restore for backups only. -->
				INSERT INTO mapping (mapping_path, parent, title, description, creator, type, commit_note, default_action_id, default_action_description<xsl:if test="@original_path">, original_path</xsl:if><xsl:if test="@date_start">, date_start</xsl:if><xsl:if test="@date_end">, date_end</xsl:if>)
				VALUES (<xsl:value-of select="$path"/>, <xsl:value-of select="$parent"/>, <xsl:value-of select="$title"/>, <xsl:value-of select="$description"/>, <xsl:value-of select="$creator"/>, '<xsl:value-of select="$type"/>', <xsl:value-of select="$commit_note"/>, <xsl:value-of select="$default_action_id"/>, <xsl:value-of select="$default_action_description"/>
					<xsl:if test="@original_path">, '<xsl:value-of select="@original_path"/>'</xsl:if>
					<xsl:if test="@date_start">, '<xsl:value-of select="@date_start"/>'</xsl:if>
					<xsl:if test="@date_end">, '<xsl:value-of select="@date_end"/>'</xsl:if>);
			</xsl:when>
			<xsl:otherwise>
				INSERT INTO mapping (mapping_path, parent, title, description, creator, type, commit_note, default_action_id, default_action_description)
				VALUES (<xsl:value-of select="$path"/>, <xsl:value-of select="$parent"/>, <xsl:value-of select="$title"/>, <xsl:value-of select="$description"/>, <xsl:value-of select="$creator"/>, '<xsl:value-of select="$type"/>', <xsl:value-of select="$commit_note"/>, <xsl:value-of select="$default_action_id"/>, <xsl:value-of select="$default_action_description"/>);
			</xsl:otherwise>
		</xsl:choose>

		<xsl:apply-templates select="conditions"/>
	</xsl:template>

	<xsl:template match="conditions">
		<xsl:apply-templates select="condition"/>
	</xsl:template>
	<xsl:template match="condition">
		<xsl:variable name="description">
			<xsl:choose>
				<xsl:when test="description">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(description, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		INSERT INTO condition (mapping_id, type, match, description)
		VALUES ((SELECT currval('"mapping_mapping_id_seq"'::regclass)), '<xsl:value-of select="type"/>', E'<xsl:value-of select='replace(replace(match, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>', <xsl:value-of select="$description"/>);

		<xsl:apply-templates select="actions/action"/>
	</xsl:template>

	<xsl:template match="action" mode="default_action">
		<xsl:variable name="name">
			<xsl:choose>
				<xsl:when test="name/text()">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(name, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="value">
			<xsl:choose>
				<xsl:when test="value/text()">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(value, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		INSERT INTO action (type, action_name, action_value)
		VALUES ('<xsl:value-of select="type"/>', <xsl:value-of select="$name"/>, <xsl:value-of select="$value"/>);
	</xsl:template>
	<xsl:template match="action">
		<xsl:variable name="name">
			<xsl:choose>
				<xsl:when test="name/text()">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(name, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="value">
			<xsl:choose>
				<xsl:when test="value/text()">
					<xsl:text>E'</xsl:text>
					<xsl:value-of select='replace(replace(value, "&#39;", "&#39;&#39;"), "\\", "\\\\")'/>
					<xsl:text>'</xsl:text>
				</xsl:when>
				<xsl:otherwise>NULL</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>

		INSERT INTO action (type, condition_id, action_name, action_value)
		VALUES ('<xsl:value-of select="type"/>', (SELECT currval('"condition_condition_id_seq"'::regclass)), <xsl:value-of select="$name"/>, <xsl:value-of select="$value"/>);
	</xsl:template>
</xsl:stylesheet>
