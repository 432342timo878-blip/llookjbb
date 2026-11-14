import { BarcodeScanningResult, CameraView, useCameraPermissions } from 'expo-camera';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { Button } from '../components/Button';
import { BARCODE_TYPES } from '../scanner';
import { getHistory, HistoryItem } from '../storage';
import { colors, radius, space, type, VERDICT_STYLE } from '../theme';
import { Card, Icon, IconCircle, ListRow, Notice, ScreenTitle, SectionLabel } from '../ui';

interface Props {
  busy: boolean;
  onBarcode: (barcode: string) => void;
  /** Kasvaa, kun käyttäjä painaa "Skannaa seuraava" – lukija avataan silloin heti. */
  launchRequest: number;
  /** Viimeksi skannatun tuotteen avaus. */
  onOpenRecent?: (item: HistoryItem) => void;
}


/**
 * Viivakoodit luetaan ensisijaisesti Googlen omalla lukijalla (Play-palvelut), joka tarkentaa
 * ja zoomaa itse. Sovelluksen oma kameranäkymä on varalla laitteille, joilla lukijaa ei ole.
 */
export function ScanScreen({ busy, onBarcode, launchRequest, onOpenRecent }: Props) {
  const [mode, setMode] = useState<'google' | 'camera'>('google');
  const [error, setError] = useState<string | null>(null);
  const [manual, setManual] = useState('');
  const [recent, setRecent] = useState<HistoryItem[]>([]);

  // Päivittyy, kun haku valmistuu (busy → false), jotta uusin tuote näkyy listassa.
  useEffect(() => {
    if (!busy) getHistory().then((h) => setRecent(h.slice(0, 3)));
  }, [busy]);
  const onBarcodeRef = useRef(onBarcode);
  onBarcodeRef.current = onBarcode;

  useEffect(() => {
    const sub = CameraView.onModernBarcodeScanned(({ data }) => {
      const code = data?.trim();
      if (code) onBarcodeRef.current(code);
    });
    return () => sub.remove();
  }, []);

  const launchGoogleScanner = async () => {
    setError(null);
    try {
      await CameraView.launchScanner({ barcodeTypes: BARCODE_TYPES });
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      if (/cancel/i.test(message)) return;
      // Virheviesti näytetään, jotta ongelman syy selviää kuvakaappauksesta.
      setError(`Googlen viivakoodinlukija ei käynnistynyt, käytetään sovelluksen omaa kameraa. (${message})`);
      setMode('camera');
    }
  };

  useEffect(() => {
    if (launchRequest > 0 && mode === 'google') launchGoogleScanner();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [launchRequest]);

  const submitManual = () => {
    const code = manual.replace(/\D/g, '');
    if (code.length >= 8) {
      setManual('');
      onBarcode(code);
    }
  };

  const manualRow = (
    <View style={styles.manualRow}>
      <Icon name="barcode-outline" size={20} color={colors.muted} />
      <TextInput
        value={manual}
        onChangeText={setManual}
        placeholder="Kirjoita viivakoodin numerot"
        keyboardType="number-pad"
        returnKeyType="search"
        onSubmitEditing={submitManual}
        style={styles.input}
        placeholderTextColor={colors.muted}
      />
      <Pressable onPress={submitManual} disabled={busy} hitSlop={8} style={styles.searchButton}>
        <Icon name="arrow-forward" size={20} color={colors.primaryText} />
      </Pressable>
    </View>
  );

  if (mode === 'camera') {
    return (
      <View style={{ flex: 1 }}>
        <View style={{ paddingHorizontal: space.xl }}>
          <ScreenTitle title="Kamera" onBack={() => setMode('google')} />
          {error && <Notice icon="information-circle" color={colors.yellow} bg={colors.yellowBg}>{error}</Notice>}
        </View>
        <InAppCamera busy={busy} onBarcode={onBarcode} />
        <View style={{ padding: space.lg }}>{manualRow}</View>
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
      <ScreenTitle title="FODMAP-tutka" subtitle="Skannaa tuote ja näe heti, sopiiko se vatsallesi." />

      <Pressable
        style={({ pressed }) => [styles.hero, (pressed || busy) && { opacity: 0.85 }]}
        onPress={launchGoogleScanner}
        disabled={busy}
      >
        <View style={styles.heroIcon}>
          {busy ? <ActivityIndicator color={colors.primary} /> : <Icon name="scan" size={34} color={colors.primary} />}
        </View>
        <Text style={styles.heroTitle}>{busy ? 'Haetaan tuotetta…' : 'Skannaa viivakoodi'}</Text>
        <Text style={styles.heroSubtitle}>
          {busy ? 'Etsitään Open Food Factsista ja kaupoista' : 'Avaa kameran – tulos tulee heti'}
        </Text>
      </Pressable>

      {error && <Notice icon="information-circle" color={colors.yellow} bg={colors.yellowBg}>{error}</Notice>}

      <View>
        <SectionLabel>Tai syötä käsin</SectionLabel>
        {manualRow}
      </View>

      {recent.length > 0 && onOpenRecent && (
        <View>
          <SectionLabel>Viimeksi skannatut</SectionLabel>
          <Card style={{ paddingVertical: space.xs }}>
            {recent.map((item, i) => {
              const v = VERDICT_STYLE[item.verdict];
              return (
                <ListRow
                  key={item.barcode}
                  title={item.name}
                  subtitle={item.brand}
                  leading={<IconCircle name={v.icon} color={v.color} bg={v.bg} size={34} />}
                  onPress={() => onOpenRecent(item)}
                  last={i === recent.length - 1}
                />
              );
            })}
          </Card>
        </View>
      )}

      <Pressable onPress={() => setMode('camera')} style={styles.altCamera}>
        <Icon name="camera-outline" size={16} color={colors.muted} />
        <Text style={styles.link}>Käytä sovelluksen omaa kameraa</Text>
      </Pressable>
    </ScrollView>
  );
}

/** Sama viivakoodi luetaan kameralla monta kertaa sekunnissa – ohitetaan toistot hetken ajan. */
const REPEAT_IGNORE_MS = 3000;

function InAppCamera({ busy, onBarcode }: { busy: boolean; onBarcode: (barcode: string) => void }) {
  const [permission, requestPermission] = useCameraPermissions();
  const [torch, setTorch] = useState(false);
  const last = useRef<{ code: string; at: number } | null>(null);

  const handleScan = ({ data }: BarcodeScanningResult) => {
    const code = data.trim();
    const now = Date.now();
    if (busy || !code) return;
    if (last.current && last.current.code === code && now - last.current.at < REPEAT_IGNORE_MS) return;
    last.current = { code, at: now };
    onBarcode(code);
  };

  if (!permission) return <View style={styles.center}><ActivityIndicator /></View>;

  if (!permission.granted) {
    return (
      <View style={styles.center}>
        <Text style={styles.title}>Kameran käyttölupa tarvitaan</Text>
        <Text style={styles.body}>Sovellus lukee viivakoodin kameralla. Kuvia ei tallenneta.</Text>
        <Button label="Salli kamera" onPress={requestPermission} />
      </View>
    );
  }

  return (
    <View style={styles.cameraWrap}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        enableTorch={torch}
        barcodeScannerSettings={{ barcodeTypes: BARCODE_TYPES }}
        onBarcodeScanned={busy ? undefined : handleScan}
      />
      <View style={styles.overlay} pointerEvents="none">
        <View style={styles.frame} />
        <Text style={styles.hint}>{busy ? 'Haetaan tuotetta…' : 'Osoita kamera viivakoodiin'}</Text>
        {busy && <ActivityIndicator color="#fff" size="large" style={{ marginTop: 12 }} />}
      </View>
      <Pressable style={styles.torch} onPress={() => setTorch((t) => !t)}>
        <Icon name={torch ? 'flashlight' : 'flashlight-outline'} size={16} color="#fff" />
        <Text style={styles.torchText}>{torch ? 'Valo päällä' : 'Valo'}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingBottom: space.xxl, gap: space.xl },
  hero: { backgroundColor: colors.primary, borderRadius: radius.lg + 4, paddingVertical: space.xxl, paddingHorizontal: space.xl, alignItems: 'center', gap: space.sm },
  heroIcon: { width: 72, height: 72, borderRadius: 36, backgroundColor: colors.primarySoft, alignItems: 'center', justifyContent: 'center', marginBottom: space.sm },
  heroTitle: { fontSize: 22, fontWeight: '800', color: colors.primaryText, letterSpacing: -0.3 },
  heroSubtitle: { fontSize: 14, color: '#CFE3D7' },
  manualRow: { flexDirection: 'row', alignItems: 'center', gap: space.sm, backgroundColor: colors.surface, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingLeft: space.md, paddingRight: 6, height: 54 },
  input: { flex: 1, fontSize: 16, color: colors.text, height: '100%' },
  searchButton: { width: 40, height: 40, borderRadius: radius.sm, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' },
  altCamera: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, paddingVertical: space.sm },
  link: { ...type.small, fontWeight: '600' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: space.xl, gap: space.lg },
  title: { ...type.title, textAlign: 'center' },
  body: { ...type.body, textAlign: 'center' },
  cameraWrap: { flex: 1, backgroundColor: '#000', overflow: 'hidden', marginHorizontal: space.lg, borderRadius: radius.lg },
  overlay: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' },
  frame: { width: '78%', height: 150, borderWidth: 3, borderColor: '#fff', borderRadius: 16 },
  hint: { color: '#fff', fontSize: 16, fontWeight: '600', marginTop: 16, textShadowColor: '#000', textShadowRadius: 4 },
  torch: { position: 'absolute', top: 16, right: 16, flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: 'rgba(0,0,0,0.5)', paddingHorizontal: 12, paddingVertical: 8, borderRadius: 20 },
  torchText: { color: '#fff', fontWeight: '600' },
});
