import { useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { Button } from '../components/Button';
import { photographText } from '../ocr';
import { assessStack, dailyAmount, dailyCustom, Supplement } from '../supplements/assess';
import { formatAmount, NutrientAmounts, NutrientId, NUTRIENTS, parseSupplementText, Unit } from '../supplements/nutrients';
import { colors, IconName, radius, space, type } from '../theme';
import { Card, Icon, IconCircle, Notice, ScreenTitle, SectionLabel } from '../ui';
import { LEVEL_STYLE } from './SupplementsScreen';

interface Props {
  draft: Supplement;
  /** Muut pinon valmisteet (ilman tätä) – näytetään, mitä tämän lisääminen muuttaa. */
  others: Supplement[];
  isNew: boolean;
  /** Etiketin tietoja ei löytynyt automaattisesti. */
  needsLabel?: boolean;
  /** Mistä tiedot tulivat tai miksi niitä ei löytynyt. */
  lookupInfo?: string;
  onSave: (s: Supplement) => void;
  onDelete?: () => void;
  onCancel: () => void;
}

const NEXT_UNIT: Record<Unit, Unit> = { mg: 'g', g: 'µg', 'µg': 'mg' };

const toText = (n: number | undefined) => (n === undefined ? '' : String(n).replace('.', ','));
const toNumber = (t: string) => {
  const n = parseFloat(t.replace(',', '.'));
  return Number.isFinite(n) ? n : undefined;
};

export function SupplementEditScreen({ draft, others, isNew, needsLabel, lookupInfo, onSave, onDelete, onCancel }: Props) {
  const [name, setName] = useState(draft.name);
  const [doseUnits, setDoseUnits] = useState(toText(draft.doseUnits));
  const [unitsPerDay, setUnitsPerDay] = useState(toText(draft.unitsPerDay));
  const [packSize, setPackSize] = useState(toText(draft.packSize));
  const [amounts, setAmounts] = useState<Record<string, string>>(
    Object.fromEntries(Object.entries(draft.amounts).map(([k, v]) => [k, toText(v)])),
  );
  const [custom, setCustom] = useState<{ name: string; amount: string; unit: Unit }[]>(
    (draft.custom ?? []).map((c) => ({ name: c.name, amount: toText(c.amount), unit: c.unit })),
  );
  const [packStartedAt, setPackStartedAt] = useState(draft.packStartedAt);
  const [picking, setPicking] = useState(false);
  const [reading, setReading] = useState(false);

  const current = (): Supplement => {
    const parsed: NutrientAmounts = {};
    for (const [id, text] of Object.entries(amounts)) {
      const n = toNumber(text);
      if (n !== undefined && n > 0) parsed[id as NutrientId] = n;
    }
    const pack = toNumber(packSize);
    return {
      ...draft,
      name: name.trim() || 'Nimetön lisäravinne',
      amounts: parsed,
      custom: custom
        .map((c) => ({ name: c.name.trim(), amount: toNumber(c.amount) ?? 0, unit: c.unit }))
        .filter((c) => c.name && c.amount > 0),
      doseUnits: toNumber(doseUnits) ?? 1,
      unitsPerDay: toNumber(unitsPerDay) ?? 1,
      packSize: pack,
      // Uudelle pakkaukselle aloituspäivä on tänään.
      packStartedAt: pack ? (packStartedAt ?? Date.now()) : undefined,
    };
  };

  const photograph = async () => {
    setReading(true);
    try {
      const text = await photographText();
      if (text === null) return;
      const label = parseSupplementText(text);
      if (Object.keys(label.amounts).length === 0) {
        Alert.alert('Arvoja ei tunnistettu', 'Kuvaa vitamiini- ja kivennäisainetaulukko suoraan edestä ja rajaa vain taulukko.');
        return;
      }
      setAmounts((a) => ({ ...a, ...Object.fromEntries(Object.entries(label.amounts).map(([k, v]) => [k, toText(v)])) }));
      if (label.doseUnits) {
        setDoseUnits(String(label.doseUnits));
        if (isNew) setUnitsPerDay(String(label.doseUnits));
      }
    } catch (e) {
      Alert.alert('Kuvaus epäonnistui', e instanceof Error ? e.message : String(e));
    } finally {
      setReading(false);
    }
  };

  const supplement = current();
  const before = new Set(assessStack(others).warnings.map((w) => w.text));
  const added = assessStack([...others, supplement]).warnings.filter((w) => !before.has(w.text));
  const shown = NUTRIENTS.filter((n) => n.id in amounts);
  const missing = NUTRIENTS.filter((n) => !(n.id in amounts));

  return (
    <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
      <ScreenTitle title={isNew ? 'Uusi lisäravinne' : 'Muokkaa'} onBack={onCancel} />

      {needsLabel && (
        <Notice icon="camera-outline" color={colors.yellow} bg={colors.yellowBg}>
          Vitamiinitaulukkoa ei löytynyt verkosta. Kuvaa pakkauksen taulukko, niin arvot täyttyvät.
        </Notice>
      )}
      {lookupInfo && (
        <Notice icon="information-circle-outline" color={colors.textSoft} bg={colors.surfaceAlt}>
          {lookupInfo}
        </Notice>
      )}

      <Card style={{ gap: space.md }}>
        <View style={{ gap: 6 }}>
          <Text style={type.label}>Nimi</Text>
          <TextInput value={name} onChangeText={setName} placeholder="Esim. Magnesium + B6" style={styles.input} placeholderTextColor={colors.muted} />
        </View>
        <View style={styles.row}>
          <Field label="Annos" value={doseUnits} onChange={setDoseUnits} />
          <Field label="Päivässä" value={unitsPerDay} onChange={setUnitsPerDay} />
          <Field label="Purkissa" value={packSize} onChange={setPackSize} />
        </View>
        <Text style={type.small}>Kappaleina. Annos = montako kapselia, tablettia tai mittaa etiketin arvot koskevat.</Text>
        {!isNew && supplement.packSize && (
          <Button label="Aloitin uuden purkin tänään" icon="refresh" variant="secondary" onPress={() => setPackStartedAt(Date.now())} />
        )}
      </Card>

      <View>
        <SectionLabel>Sisältö per annos ({doseUnits || '1'} kpl)</SectionLabel>
        <Card style={{ gap: space.md }}>
          <Button
            label={reading ? 'Luetaan…' : 'Kuvaa vitamiinitaulukko'}
            icon="camera-outline"
            variant={needsLabel ? 'primary' : 'secondary'}
            onPress={photograph}
            disabled={reading}
          />
          {reading && <ActivityIndicator color={colors.primary} />}

          {shown.length === 0 && custom.length === 0 && <Text style={type.body}>Ei vielä ainesosia. Kuvaa taulukko tai lisää ne alta.</Text>}
          {shown.map((def) => (
            <View key={def.id} style={styles.nutrientRow}>
              <Text style={[type.bodyStrong, { flex: 1 }]}>{def.name}</Text>
              <TextInput
                value={amounts[def.id]}
                onChangeText={(t) => setAmounts((a) => ({ ...a, [def.id]: t }))}
                keyboardType="decimal-pad"
                placeholder="0"
                placeholderTextColor={colors.muted}
                style={styles.amountInput}
              />
              <Text style={styles.unit}>{def.unit}</Text>
              <RemoveButton
                onPress={() =>
                  setAmounts((a) => {
                    const next = { ...a };
                    delete next[def.id];
                    return next;
                  })
                }
              />
            </View>
          ))}

          {custom.map((c, i) => (
            <View key={`custom-${i}`} style={styles.nutrientRow}>
              <TextInput
                value={c.name}
                onChangeText={(t) => setCustom((list) => list.map((x, j) => (j === i ? { ...x, name: t } : x)))}
                placeholder="Ainesosa, esim. MSM"
                style={[styles.amountInput, styles.customName]}
                placeholderTextColor={colors.muted}
              />
              <TextInput
                value={c.amount}
                onChangeText={(t) => setCustom((list) => list.map((x, j) => (j === i ? { ...x, amount: t } : x)))}
                keyboardType="decimal-pad"
                placeholder="0"
                placeholderTextColor={colors.muted}
                style={styles.amountInput}
              />
              {/* Yksikkö vaihtuu napauttamalla: mg → g → µg. */}
              <Pressable
                onPress={() => setCustom((list) => list.map((x, j) => (j === i ? { ...x, unit: NEXT_UNIT[x.unit] } : x)))}
                style={styles.unitToggle}
                hitSlop={6}
              >
                <Text style={styles.unitToggleText}>{c.unit}</Text>
              </Pressable>
              <RemoveButton onPress={() => setCustom((list) => list.filter((_, j) => j !== i))} />
            </View>
          ))}

          <View style={styles.addRow}>
            <AddLink label={picking ? 'Sulje lista' : 'Ravintoaine'} icon={picking ? 'close' : 'add'} onPress={() => setPicking((p) => !p)} />
            <AddLink label="Oma ainesosa" icon="add" onPress={() => setCustom((list) => [...list, { name: '', amount: '', unit: 'mg' }])} />
          </View>
          {picking && (
            <View style={styles.chips}>
              {missing.map((def) => (
                <Pressable
                  key={def.id}
                  style={({ pressed }) => [styles.chip, pressed && { backgroundColor: colors.primarySoft }]}
                  onPress={() => {
                    setAmounts((a) => ({ ...a, [def.id]: '' }));
                    setPicking(false);
                  }}
                >
                  <Text style={styles.chipText}>{def.name}</Text>
                </Pressable>
              ))}
            </View>
          )}
          <Text style={type.small}>Oma ainesosa = mikä tahansa, jota listalla ei ole. Yksikkö vaihtuu napauttamalla.</Text>
        </Card>
      </View>

      <View>
        <SectionLabel>{isNew ? 'Jos lisäät tämän pinoosi' : 'Vaikutus pinoosi'}</SectionLabel>
        <Card style={{ gap: space.md }}>
          {added.length === 0 ? (
            <View style={styles.okRow}>
              <IconCircle name="checkmark" color={colors.surface} bg={colors.green} size={32} />
              <Text style={[type.bodyStrong, { flex: 1, color: colors.green }]}>Ei uusia huomioita – sopii nykyiseen pinoosi.</Text>
            </View>
          ) : (
            added.map((w, i) => (
              <Notice key={i} icon={LEVEL_STYLE[w.level].icon} color={LEVEL_STYLE[w.level].color} bg={LEVEL_STYLE[w.level].bg}>
                {w.text}
              </Notice>
            ))
          )}
          {(shown.length > 0 || (supplement.custom ?? []).length > 0) && (
            <View style={styles.daily}>
              <Text style={type.label}>Tästä valmisteesta päivässä</Text>
              {shown.map((def) => (
                <View key={def.id} style={styles.dailyRow}>
                  <Text style={[type.body, { flex: 1 }]}>{def.name}</Text>
                  <Text style={type.bodyStrong}>{formatAmount(dailyAmount(supplement, def.id), def.unit)}</Text>
                </View>
              ))}
              {(supplement.custom ?? []).map((c, i) => (
                <View key={`c${i}`} style={styles.dailyRow}>
                  <Text style={[type.body, { flex: 1 }]}>{c.name}</Text>
                  <Text style={type.bodyStrong}>{formatAmount(dailyCustom(supplement, c), c.unit)}</Text>
                </View>
              ))}
            </View>
          )}
        </Card>
      </View>

      <View style={{ gap: space.sm }}>
        <Button label={isNew ? 'Lisää pinoon' : 'Tallenna'} icon={isNew ? 'add' : 'checkmark'} onPress={() => onSave(current())} />
        {onDelete && (
          <Button
            label="Poista pinosta"
            icon="trash-outline"
            variant="ghost"
            onPress={() =>
              Alert.alert('Poistetaanko?', name, [
                { text: 'Peruuta', style: 'cancel' },
                { text: 'Poista', style: 'destructive', onPress: onDelete },
              ])
            }
          />
        )}
      </View>
    </ScrollView>
  );
}

function Field({ label, value, onChange }: { label: string; value: string; onChange: (t: string) => void }) {
  return (
    <View style={{ flex: 1, gap: 6 }}>
      <Text style={type.label} numberOfLines={1}>
        {label}
      </Text>
      <TextInput value={value} onChangeText={onChange} keyboardType="decimal-pad" style={[styles.input, { textAlign: 'center' }]} />
    </View>
  );
}

function RemoveButton({ onPress }: { onPress: () => void }) {
  return (
    <Pressable onPress={onPress} hitSlop={8} style={{ padding: 2 }}>
      <Icon name="close-circle" size={20} color={colors.muted} />
    </Pressable>
  );
}

function AddLink({ label, icon, onPress }: { label: string; icon: IconName; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.addLink, pressed && { opacity: 0.6 }]}>
      <Icon name={icon} size={18} color={colors.primary} />
      <Text style={styles.addLinkText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingBottom: space.xxl, gap: space.lg },
  input: { backgroundColor: colors.surfaceAlt, borderRadius: radius.sm, paddingHorizontal: space.md, paddingVertical: 10, fontSize: 16, color: colors.text },
  row: { flexDirection: 'row', gap: space.sm },
  nutrientRow: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
  amountInput: { width: 76, backgroundColor: colors.surfaceAlt, borderRadius: radius.sm, paddingHorizontal: 10, paddingVertical: 8, fontSize: 15, textAlign: 'right', color: colors.text },
  unit: { width: 30, fontSize: 14, color: colors.textSoft },
  customName: { flex: 1, width: undefined, textAlign: 'left' },
  unitToggle: { width: 30, alignItems: 'center', paddingVertical: 4, borderRadius: radius.sm, backgroundColor: colors.primarySoft },
  unitToggleText: { fontSize: 13, color: colors.primary, fontWeight: '700' },
  addRow: { flexDirection: 'row', gap: space.sm },
  addLink: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, paddingVertical: 10, borderRadius: radius.md, borderWidth: 1, borderStyle: 'dashed', borderColor: colors.primary },
  addLinkText: { fontSize: 14, color: colors.primary, fontWeight: '700' },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  chip: { borderWidth: 1, borderColor: colors.border, backgroundColor: colors.surface, borderRadius: radius.pill, paddingHorizontal: 12, paddingVertical: 7 },
  chipText: { fontSize: 13, color: colors.text, fontWeight: '600' },
  okRow: { flexDirection: 'row', alignItems: 'center', gap: space.md },
  daily: { gap: 6, backgroundColor: colors.surfaceAlt, borderRadius: radius.md, padding: space.md },
  dailyRow: { flexDirection: 'row', alignItems: 'baseline', gap: space.sm },
});
