import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { assessStack, daysLeft, Level, NutrientTotal, Supplement } from '../supplements/assess';
import { DbMatch, searchSupplements, supplementDbSize } from '../supplements/database';
import { formatAmount, NUTRIENT_BY_ID } from '../supplements/nutrients';
import { colors, IconName, radius, space, type } from '../theme';
import { Card, EmptyState, Icon, IconCircle, ListRow, Notice, Pill, ScreenTitle, SearchField, SectionLabel } from '../ui';

interface Props {
  supplements: Supplement[];
  busy: boolean;
  onScan: () => void;
  onAddManually: () => void;
  onOpen: (s: Supplement) => void;
  onPick: (match: DbMatch) => void;
}

export const LEVEL_STYLE: Record<Level, { color: string; bg: string; icon: IconName }> = {
  bad: { color: colors.red, bg: colors.redBg, icon: 'close-circle' },
  caution: { color: colors.yellow, bg: colors.yellowBg, icon: 'alert-circle' },
  info: { color: colors.primary, bg: colors.primarySoft, icon: 'information-circle' },
};

const STATUS_COLOR: Record<NutrientTotal['status'], string> = { over: colors.red, ok: colors.green, low: colors.yellow, none: colors.primary };

export function SupplementsScreen({ supplements, busy, onScan, onAddManually, onOpen, onPick }: Props) {
  const { totals, customTotals, warnings } = assessStack(supplements);
  const [query, setQuery] = useState('');
  const searching = query.trim().length >= 2;
  const results = searching ? searchSupplements(query) : [];

  return (
    <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
      <ScreenTitle
        title="Ravinteet"
        subtitle={supplements.length > 0 ? `${supplements.length} lisäravinnetta käytössä` : 'Lisäravinteesi yhdessä paikassa'}
      />

      <View style={{ gap: space.md }}>
        <Pressable onPress={onScan} disabled={busy} style={({ pressed }) => [styles.scan, pressed && { opacity: 0.85 }]}>
          <View style={styles.scanIcon}>
            {busy ? <ActivityIndicator color={colors.primaryText} /> : <Icon name="scan" size={24} color={colors.primaryText} />}
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.scanTitle}>{busy ? 'Haetaan tietoja…' : 'Skannaa lisäravinne'}</Text>
            <Text style={styles.scanSub}>Purkin viivakoodista</Text>
          </View>
          <Icon name="chevron-forward" size={20} color={colors.primaryText} />
        </Pressable>

        {supplementDbSize > 0 && (
          <SearchField value={query} onChange={setQuery} placeholder={`Hae nimellä (${supplementDbSize} tuotetta)`} />
        )}

        {searching && (
          <Card style={{ paddingVertical: space.xs }}>
            {results.length === 0 ? (
              <Text style={[type.body, { paddingVertical: space.md }]}>Ei osumia. Voit lisätä tuotteen itse alta.</Text>
            ) : (
              results.map((m, i) => (
                <ListRow
                  key={`${m.name}-${i}`}
                  title={m.name}
                  subtitle={[m.brand, m.shop].filter(Boolean).join(' · ')}
                  leading={<IconCircle name="add" color={colors.primary} bg={colors.primarySoft} size={32} />}
                  onPress={() => {
                    setQuery('');
                    onPick(m);
                  }}
                  last={i === results.length - 1}
                />
              ))
            )}
          </Card>
        )}

        <Pressable onPress={onAddManually} style={styles.link} hitSlop={8}>
          <Icon name="create-outline" size={18} color={colors.primary} />
          <Text style={styles.linkText}>Lisää itse ilman viivakoodia</Text>
        </Pressable>
      </View>

      {supplements.length === 0 ? (
        <EmptyState
          icon="flask-outline"
          title="Pino on tyhjä"
          body="Lisää käyttämäsi lisäravinteet, niin näet päivittäisen kokonaissaannin, ylärajat, päällekkäisyydet, vatsalle hankalat aineet ja milloin purkki loppuu."
        />
      ) : (
        <>
          {warnings.length > 0 && (
            <View>
              <SectionLabel>Huomiot</SectionLabel>
              <View style={{ gap: space.sm }}>
                {warnings.map((w, i) => (
                  <Notice key={i} icon={LEVEL_STYLE[w.level].icon} color={LEVEL_STYLE[w.level].color} bg={LEVEL_STYLE[w.level].bg}>
                    {w.text}
                  </Notice>
                ))}
              </View>
            </View>
          )}

          <View>
            <SectionLabel>Pinosi</SectionLabel>
            <Card style={{ paddingVertical: space.xs }}>
              {supplements.map((s, i) => {
                const left = daysLeft(s);
                const low = left !== undefined && left <= 7;
                return (
                  <ListRow
                    key={s.id}
                    title={s.name}
                    subtitle={`${String(s.unitsPerDay).replace('.', ',')} kpl päivässä`}
                    leading={<IconCircle name="flask" color={colors.primary} bg={colors.primarySoft} size={36} />}
                    trailing={
                      <View style={styles.trailing}>
                        {left !== undefined && (
                          <Pill
                            label={left > 0 ? `${left} pv` : 'Loppu'}
                            icon={low ? 'alert-circle' : 'hourglass-outline'}
                            color={low ? colors.red : colors.textSoft}
                            bg={low ? colors.redBg : colors.surfaceAlt}
                          />
                        )}
                        <Icon name="chevron-forward" size={18} color={colors.muted} />
                      </View>
                    }
                    onPress={() => onOpen(s)}
                    last={i === supplements.length - 1}
                  />
                );
              })}
            </Card>
          </View>

          {(totals.length > 0 || customTotals.length > 0) && (
            <View>
              <SectionLabel>Päivittäinen saanti lisäravinteista</SectionLabel>
              <Card style={{ gap: space.lg }}>
                {totals.map((t) => (
                  <TotalRow key={t.id} total={t} />
                ))}
                {customTotals.map((t) => (
                  <View key={`${t.name}|${t.unit}`} style={styles.totalHead}>
                    <Text style={[type.bodyStrong, { flex: 1 }]}>{t.name}</Text>
                    <Text style={type.bodyStrong}>{formatAmount(t.total, t.unit)}</Text>
                  </View>
                ))}
                <Text style={type.small}>Ruoasta tulee lisäksi. Suositus = EU:n viitearvo, max = EFSA:n turvallinen yläraja (aikuiset).</Text>
              </Card>
            </View>
          )}
        </>
      )}
      <Text style={styles.disclaimer}>Arviot ovat yleisiä aikuisten raja-arvoja eivätkä korvaa lääkärin tai ravitsemusterapeutin ohjeita.</Text>
    </ScrollView>
  );
}

/** Ravinteen määrä palkkina: täysi palkki = yläraja (tai suositus, jos ylärajaa ei ole). */
function TotalRow({ total }: { total: NutrientTotal }) {
  const def = NUTRIENT_BY_ID[total.id];
  const scale = def.ul ?? def.ri;
  const fill = scale ? Math.min(total.total / scale, 1) : 0;
  const riMark = def.ul !== undefined && def.ri !== undefined && def.ri < def.ul ? def.ri / def.ul : undefined;
  const color = STATUS_COLOR[total.status];
  const limits = [def.ri !== undefined && `suositus ${formatAmount(def.ri, def.unit)}`, def.ul !== undefined && `max ${formatAmount(def.ul, def.unit)}`]
    .filter(Boolean)
    .join(' · ');
  return (
    <View style={{ gap: 6 }}>
      <View style={styles.totalHead}>
        <Text style={[type.bodyStrong, { flex: 1 }]}>{def.name}</Text>
        <Text style={[type.bodyStrong, { color: total.status === 'over' ? colors.red : colors.text }]}>{formatAmount(total.total, def.unit)}</Text>
      </View>
      {scale !== undefined && (
        <View style={styles.track}>
          <View style={[styles.fill, { width: `${Math.max(fill * 100, 3)}%`, backgroundColor: color }]} />
          {riMark !== undefined && <View style={[styles.riMark, { left: `${riMark * 100}%` }]} />}
        </View>
      )}
      {limits ? <Text style={type.small}>{limits}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingBottom: space.xxl, gap: space.xl },
  scan: { flexDirection: 'row', alignItems: 'center', gap: space.md, backgroundColor: colors.primary, borderRadius: radius.lg, padding: space.lg },
  scanIcon: { width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(255,255,255,0.16)', alignItems: 'center', justifyContent: 'center' },
  scanTitle: { fontSize: 17, fontWeight: '700', color: colors.primaryText },
  scanSub: { fontSize: 13, color: colors.primaryText, opacity: 0.8, marginTop: 2 },
  link: { flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'center', padding: 4 },
  linkText: { fontSize: 15, color: colors.primary, fontWeight: '700' },
  trailing: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
  totalHead: { flexDirection: 'row', alignItems: 'baseline', gap: space.sm },
  track: { height: 8, borderRadius: 4, backgroundColor: colors.surfaceAlt, overflow: 'hidden' },
  fill: { height: '100%', borderRadius: 4 },
  riMark: { position: 'absolute', top: 0, bottom: 0, width: 2, backgroundColor: colors.textSoft, opacity: 0.5 },
  disclaimer: { ...type.small, textAlign: 'center' },
});
