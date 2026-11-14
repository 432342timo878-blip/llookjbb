import { Alert, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { Button } from '../components/Button';
import { FodmapGroup, GROUP_DESCRIPTIONS, GROUP_LABELS } from '../data/ingredients';
import { clearHistory, Settings } from '../storage';
import { colors, space, type } from '../theme';
import { Card, ScreenTitle, SectionLabel } from '../ui';

interface Props {
  settings: Settings;
  onChange: (settings: Settings) => void;
}

const GROUPS = Object.keys(GROUP_LABELS) as FodmapGroup[];

export function SettingsScreen({ settings, onChange }: Props) {
  const toggle = (group: FodmapGroup, tolerated: boolean) => {
    const next = new Set(settings.tolerated);
    if (tolerated) next.add(group);
    else next.delete(group);
    onChange({ ...settings, tolerated: GROUPS.filter((g) => next.has(g)) });
  };

  const confirmClear = () =>
    Alert.alert('Tyhjennä historia?', 'Skannaushistoria poistetaan. Omat merkinnät ja kirjoittamasi ainesosaluettelot säilyvät.', [
      { text: 'Peruuta', style: 'cancel' },
      { text: 'Tyhjennä', style: 'destructive', onPress: () => clearHistory() },
    ]);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <ScreenTitle title="Asetukset" />

      <View>
        <SectionLabel>Omat sietorajat</SectionLabel>
        <Text style={[type.body, { marginBottom: space.md }]}>
          Jos olet testannut (esim. eliminaatiodieetin palautusvaiheessa), että siedät jonkin FODMAP-ryhmän, kytke se päälle. Sen
          ainesosat eivät silloin vaikuta tulokseen.
        </Text>
        <Card style={{ paddingVertical: space.xs }}>
          {GROUPS.map((g, i) => {
            const tolerated = settings.tolerated.includes(g);
            return (
              <View key={g} style={[styles.row, i < GROUPS.length - 1 && styles.divider]}>
                <View style={{ flex: 1 }}>
                  <Text style={type.bodyStrong}>{GROUP_LABELS[g]}</Text>
                  <Text style={[type.small, { marginTop: 2 }]}>{GROUP_DESCRIPTIONS[g]}</Text>
                  <Text style={[styles.state, { color: tolerated ? colors.green : colors.muted }]}>{tolerated ? 'Siedän' : 'Herkkä'}</Text>
                </View>
                <Switch
                  value={tolerated}
                  onValueChange={(v) => toggle(g, v)}
                  trackColor={{ true: colors.primary, false: colors.border }}
                  thumbColor={colors.surface}
                />
              </View>
            );
          })}
        </Card>
      </View>

      <View>
        <SectionLabel>Tiedot</SectionLabel>
        <Button label="Tyhjennä skannaushistoria" icon="trash-outline" variant="secondary" onPress={confirmClear} />
      </View>

      <View>
        <SectionLabel>Miten arvio tehdään</SectionLabel>
        <Card style={{ gap: space.md }}>
          <Text style={type.body}>
            Tuotetiedot haetaan Open Food Factsista ja kauppojen verkkopalveluista (S-kaupat, K-Ruoka, Tokmanni). Arvio perustuu
            ainesosaluetteloon: määriä ei tiedetä, joten luettelon alkupään ainesosat painavat enemmän.
          </Text>
          <Text style={type.body}>Sipuli, valkosipuli, inuliini ja polyolit merkitään aina, koska ne aiheuttavat oireita jo pieninä määrinä.</Text>
          <Text style={type.small}>Tulos on suuntaa-antava eikä korvaa ravitsemusterapeutin ohjeita.</Text>
        </Card>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingBottom: space.xxl, gap: space.xl },
  row: { flexDirection: 'row', alignItems: 'center', gap: space.md, paddingVertical: space.md },
  divider: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: colors.border },
  state: { fontSize: 12, fontWeight: '700', marginTop: 4 },
});
