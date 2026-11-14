import { useState } from 'react';
import { Alert, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { Button } from '../components/Button';
import { photographIngredients } from '../ocr';
import { colors, radius, space, type } from '../theme';
import { Card, Notice, ScreenTitle, SectionLabel } from '../ui';

interface Props {
  /** Kun viivakoodi on annettu, luettelo tallennetaan tuotteelle seuraavia skannauksia varten. */
  barcode?: string;
  initialName?: string;
  initialText?: string;
  onSubmit: (name: string, text: string) => void;
  /** Avaa verkkokauppahaun sovelluksen sisällä. */
  onSearchStores?: (query: string) => void;
  onCancel?: () => void;
  /** Miksi tuotetta ei löytynyt (kauppakohtaiset syyt). */
  lookupInfo?: string;
}

export function IngredientsScreen({ barcode, initialName = '', initialText = '', onSubmit, onSearchStores, onCancel, lookupInfo }: Props) {
  const [name, setName] = useState(initialName);
  const [text, setText] = useState(initialText);
  const [recognizing, setRecognizing] = useState(false);
  const [recognized, setRecognized] = useState(false);

  const photograph = async () => {
    setRecognizing(true);
    try {
      const result = await photographIngredients();
      if (result === null) return;
      if (result.length < 5) {
        Alert.alert('Tekstiä ei tunnistettu', 'Kuvaa ainesosaluettelo läheltä ja hyvässä valossa, ja rajaa vain luettelo.');
        return;
      }
      setText(result);
      setRecognized(true);
    } catch (e) {
      Alert.alert('Kuvaus epäonnistui', e instanceof Error ? e.message : String(e));
    } finally {
      setRecognizing(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
      <ScreenTitle
        title={barcode ? 'Tuotetta ei löytynyt' : 'Tarkista'}
        subtitle={
          barcode
            ? `Viivakoodi ${barcode}. Kuvaa ainesosaluettelo tai etsi tuote verkkokaupoista. Tiedot tallentuvat, joten ensi kerralla tulos tulee heti.`
            : 'Kuvaa pakkauksen ainesosaluettelo tai liitä se tekstinä, niin näet sopiiko tuote.'
        }
        onBack={onCancel}
      />

      {lookupInfo && (
        <Notice icon="information-circle-outline" color={colors.textSoft} bg={colors.surfaceAlt}>
          {lookupInfo}
        </Notice>
      )}

      <View style={{ gap: space.sm }}>
        <Button
          label={recognizing ? 'Tunnistetaan tekstiä…' : 'Kuvaa ainesosaluettelo'}
          icon="camera-outline"
          onPress={photograph}
          disabled={recognizing}
        />
        {barcode && onSearchStores && (
          <Button label="Etsi verkkokaupoista" icon="globe-outline" variant="secondary" onPress={() => onSearchStores(barcode)} />
        )}
      </View>

      <View>
        <SectionLabel>{barcode ? 'Tai kirjoita itse' : 'Ainesosaluettelo'}</SectionLabel>
        <Card style={{ gap: space.md }}>
          {barcode && (
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder="Tuotteen nimi"
              style={styles.input}
              placeholderTextColor={colors.muted}
            />
          )}
          <TextInput
            value={text}
            onChangeText={(t) => {
              setText(t);
              setRecognized(false);
            }}
            placeholder="Esim. vehnäjauho, sokeri, kasvirasva, suola…"
            multiline
            textAlignVertical="top"
            autoCapitalize="none"
            style={[styles.input, styles.textArea]}
            placeholderTextColor={colors.muted}
          />
          {recognized && <Text style={type.small}>Tunnistettu kuvasta. Tarkista teksti ja korjaa tarvittaessa.</Text>}
        </Card>
      </View>

      <Button label="Tarkista" icon="checkmark" onPress={() => onSubmit(name, text)} disabled={text.trim().length === 0} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingBottom: space.xxl, gap: space.lg },
  input: { backgroundColor: colors.surfaceAlt, borderRadius: radius.md, paddingHorizontal: space.md, paddingVertical: 12, fontSize: 16, color: colors.text },
  textArea: { minHeight: 150 },
});
