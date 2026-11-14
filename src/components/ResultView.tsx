import { ReactNode, useState } from 'react';
import { Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Analysis, Finding } from '../analysis/analyze';
import { Product } from '../api/openFoodFacts';
import { GROUP_LABELS } from '../data/ingredients';
import { Override } from '../storage';
import { colors, radius, SEVERITY_BG, SEVERITY_COLOR, space, type, VERDICT_STYLE } from '../theme';
import { Card, Icon, IconCircle, Notice, Pill, SectionLabel } from '../ui';
import { Button } from './Button';

interface Props {
  product?: Product;
  ingredientsText?: string;
  analysis: Analysis;
  override?: Override;
  offline?: boolean;
  /** Sydänmerkki-osio (virallinen merkki ja kriteeriarvio). */
  heartSection?: ReactNode;
  onOverride?: (value: Override | null) => void;
  onEditIngredients?: () => void;
  /** Käyttäjä vahvistaa pakkauksesta, että tuote on laktoositon. */
  onMarkLactoseFree?: () => void;
  onBack?: () => void;
  onDone: () => void;
  doneLabel?: string;
}

const SEVERITY_LABEL = { bad: 'Välttää', caution: 'Varo', ok: 'Ok' } as const;

export function ResultView({
  product,
  ingredientsText,
  analysis,
  override,
  offline,
  heartSection,
  onOverride,
  onEditIngredients,
  onMarkLactoseFree,
  onBack,
  onDone,
  doneLabel = 'Skannaa seuraava',
}: Props) {
  const [showIngredients, setShowIngredients] = useState(false);
  const verdict = VERDICT_STYLE[analysis.verdict];
  const text = product?.ingredientsText ?? ingredientsText;
  const lactoseFlagged = !analysis.lactoseFree && analysis.findings.some((f) => f.severity !== 'ok' && f.entry.groups.includes('laktoosi'));

  return (
    <ScrollView contentContainerStyle={styles.container}>
      {onBack && (
        <Pressable onPress={onBack} hitSlop={12} style={styles.back}>
          <Icon name="chevron-back" size={22} color={colors.primary} />
          <Text style={styles.backText}>Takaisin</Text>
        </Pressable>
      )}

      {product && (
        <View style={styles.productRow}>
          <View style={styles.imageBox}>
            {product.imageUrl ? (
              <Image source={{ uri: product.imageUrl }} style={styles.image} />
            ) : (
              <Icon name="cube-outline" size={28} color={colors.muted} />
            )}
          </View>
          <View style={{ flex: 1, gap: 4 }}>
            <Text style={type.title} numberOfLines={3}>
              {product.name}
            </Text>
            {product.brand ? <Text style={type.body}>{product.brand}</Text> : null}
            <View style={styles.pills}>
              <Pill label={SOURCE_LABEL[product.source]} icon="pricetag-outline" />
              {offline && <Pill label="Offline" icon="cloud-offline-outline" />}
            </View>
          </View>
        </View>
      )}

      <View style={[styles.verdict, { backgroundColor: verdict.bg }]}>
        <IconCircle name={verdict.icon} color={colors.surface} bg={verdict.color} size={52} />
        <View style={{ flex: 1 }}>
          <Text style={[styles.verdictTitle, { color: verdict.color }]}>{verdict.title}</Text>
          <Text style={[type.body, { color: colors.text }]}>{verdict.subtitle}</Text>
        </View>
      </View>

      {override && (
        <Notice icon={override === 'ok' ? 'thumbs-up' : 'thumbs-down'} color={override === 'ok' ? colors.green : colors.red} bg={colors.surface}>
          Oma merkintäsi: {override === 'ok' ? 'sopii minulle' : 'ei sovi minulle'}
        </Notice>
      )}

      {analysis.certifiedLowFodmap && (
        <Notice icon="ribbon-outline" color={colors.green} bg={colors.greenBg}>
          Merkitty vähä-FODMAP-tuotteeksi (esim. Vatsaystävällinen, Low FODMAP). Valmistustapa, kuten entsyymikäsittely tai pitkä
          hapatus, hajottaa FODMAPeja, vaikka ainesosissa olisi vehnää.
        </Notice>
      )}

      {analysis.findings.length > 0 && (
        <View>
          <SectionLabel>Huomioitavat ainesosat</SectionLabel>
          <Card style={{ paddingVertical: space.sm }}>
            {analysis.findings.map((f, i) => (
              <FindingRow key={f.entry.id} finding={f} last={i === analysis.findings.length - 1} />
            ))}
          </Card>
        </View>
      )}

      {lactoseFlagged && onMarkLactoseFree && (
        <Button label="Pakkauksessa lukee: laktoositon" icon="checkmark-circle-outline" variant="secondary" onPress={onMarkLactoseFree} />
      )}

      {analysis.verdict === 'green' && analysis.safe.length > 0 && (
        <Text style={type.small}>Tunnistetut ainesosat: {analysis.safe.map((f) => f.entry.name.toLowerCase()).join(', ')}.</Text>
      )}

      {heartSection}

      {text ? (
        <Card style={{ paddingVertical: space.md }}>
          <Pressable onPress={() => setShowIngredients((v) => !v)} style={styles.expand}>
            <Icon name="list-outline" size={18} color={colors.textSoft} />
            <Text style={[type.bodyStrong, { flex: 1 }]}>Ainesosaluettelo</Text>
            <Icon name={showIngredients ? 'chevron-up' : 'chevron-down'} size={18} color={colors.muted} />
          </Pressable>
          {showIngredients && <Text style={[type.body, { marginTop: space.md }]}>{text}</Text>}
          {analysis.unrecognized.length > 0 && (
            <Text style={[type.small, { marginTop: space.sm }]}>Ei tunnistettu: {analysis.unrecognized.join(', ')}</Text>
          )}
        </Card>
      ) : null}

      {onOverride && (
        <View>
          <SectionLabel>Oma kokemuksesi</SectionLabel>
          <View style={styles.buttonRow}>
            <Button
              label="Sopii"
              icon={override === 'ok' ? 'thumbs-up' : 'thumbs-up-outline'}
              variant={override === 'ok' ? 'primary' : 'secondary'}
              onPress={() => onOverride(override === 'ok' ? null : 'ok')}
              style={{ flex: 1 }}
            />
            <Button
              label="Ei sovi"
              icon={override === 'bad' ? 'thumbs-down' : 'thumbs-down-outline'}
              variant={override === 'bad' ? 'primary' : 'secondary'}
              onPress={() => onOverride(override === 'bad' ? null : 'bad')}
              style={{ flex: 1 }}
            />
          </View>
        </View>
      )}

      <View style={{ gap: space.sm }}>
        <Button label={doneLabel} icon={doneLabel === 'Skannaa seuraava' ? 'scan' : undefined} onPress={onDone} />
        {onEditIngredients && (
          <Button
            label={analysis.verdict === 'unknown' ? 'Kuvaa tai kirjoita ainesosat' : 'Korjaa ainesosaluettelo'}
            icon="create-outline"
            variant="ghost"
            onPress={onEditIngredients}
          />
        )}
      </View>

      <Text style={styles.disclaimer}>
        Arvio perustuu ainesosaluetteloon, ei määriin. Se on suuntaa-antava eikä korvaa ravitsemusterapeutin ohjeita.
      </Text>
    </ScrollView>
  );
}

const SOURCE_LABEL: Record<Product['source'], string> = {
  off: 'Open Food Facts',
  skaupat: 'S-kaupat',
  kruoka: 'K-Ruoka',
  tokmanni: 'Tokmanni',
  manual: 'Oma merkintä',
  web: 'Jaettu sivu',
};

function FindingRow({ finding, last }: { finding: Finding; last: boolean }) {
  const color = SEVERITY_COLOR[finding.severity];
  return (
    <View style={[styles.finding, !last && styles.findingDivider]}>
      <View style={[styles.findingBar, { backgroundColor: color }]} />
      <View style={{ flex: 1, gap: 4 }}>
        <View style={styles.findingHead}>
          <Text style={[type.heading, { flex: 1 }]}>
            {finding.entry.name}
            {finding.percent !== undefined ? ` · ${String(finding.percent).replace('.', ',')} %` : ''}
          </Text>
          <Pill label={SEVERITY_LABEL[finding.severity]} color={color} bg={SEVERITY_BG[finding.severity]} />
        </View>
        <Text style={[type.body, { color: colors.text }]}>{finding.reason}</Text>
        {/* Näytetään luettelon oma sana: "Inuliini" voi tarkoittaa esim. oligofruktoosia. */}
        {finding.matchedText ? <Text style={styles.quote}>“{finding.matchedText}”</Text> : null}
        {(finding.entry.groups.length > 0 || finding.entry.note) && (
          <Text style={type.small}>
            {finding.entry.groups.map((g) => GROUP_LABELS[g]).join(' · ')}
            {finding.entry.groups.length > 0 && finding.entry.note ? ' — ' : ''}
            {finding.entry.note}
          </Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingTop: space.md, paddingBottom: space.xxl, gap: space.xl },
  back: { flexDirection: 'row', alignItems: 'center', gap: 2, marginLeft: -4, alignSelf: 'flex-start', marginBottom: -space.sm },
  backText: { fontSize: 16, color: colors.primary, fontWeight: '600' },
  productRow: { flexDirection: 'row', gap: space.lg, alignItems: 'flex-start' },
  imageBox: { width: 76, height: 76, borderRadius: radius.md, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  image: { width: '100%', height: '100%' },
  pills: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 4 },
  verdict: { flexDirection: 'row', alignItems: 'center', gap: space.lg, padding: space.xl, borderRadius: radius.lg },
  verdictTitle: { fontSize: 21, fontWeight: '800', letterSpacing: -0.3, marginBottom: 2 },
  finding: { flexDirection: 'row', gap: space.md, paddingVertical: space.md },
  findingDivider: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: colors.border },
  findingBar: { width: 4, borderRadius: 2 },
  findingHead: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
  quote: { fontSize: 13, color: colors.textSoft, fontStyle: 'italic', backgroundColor: colors.surfaceAlt, paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6, alignSelf: 'flex-start' },
  expand: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
  buttonRow: { flexDirection: 'row', gap: space.sm },
  disclaimer: { ...type.small, textAlign: 'center' },
});
