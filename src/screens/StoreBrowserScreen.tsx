import { ComponentType, Ref, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import WebView, { WebViewMessageEvent } from 'react-native-webview';
import type { WebViewProps } from 'react-native-webview/lib/WebView';

import { extractionScript, parseMessage, StoreId, StoreProduct, STORES, STORE_BY_ID } from '../api/stores';
import { Button } from '../components/Button';
import { colors, radius, space, type } from '../theme';
import { Icon } from '../ui';

interface Props {
  query: string;
  onFound: (product: StoreProduct) => void;
  onCancel: () => void;
}

interface WebViewHandle {
  injectJavaScript: (script: string) => void;
}
// Kirjaston tyypit eivät kerro, että Android-WebView ottaa ref-viittauksen (forwardRef).
const RefWebView = WebView as unknown as ComponentType<WebViewProps & { ref?: Ref<WebViewHandle> }>;

/** Verkkokauppa sovelluksen sisällä: käyttäjä etsii tuotteen ja sovellus lukee tiedot sivulta. */
export function StoreBrowserScreen({ query, onFound, onCancel }: Props) {
  const web = useRef<WebViewHandle>(null);
  const [storeId, setStoreId] = useState<StoreId>('skaupat');
  const [reading, setReading] = useState(false);
  const store = STORE_BY_ID[storeId];

  const read = () => {
    setReading(true);
    // Sama skripti kuin automaattisessa haussa, mutta vain nykyiseltä sivulta.
    web.current?.injectJavaScript(`window.__fodmapTutka = false; ${extractionScript(store, '')}`);
  };

  return (
    <View style={{ flex: 1 }}>
      <View style={styles.top}>
        <Pressable onPress={onCancel} hitSlop={12} style={styles.back}>
          <Icon name="chevron-back" size={22} color={colors.primary} />
          <Text style={styles.backText}>Takaisin</Text>
        </Pressable>
        <View style={styles.segment}>
          {STORES.map((s) => (
            <Pressable key={s.id} onPress={() => setStoreId(s.id)} style={[styles.tab, s.id === storeId && styles.tabActive]}>
              <Text style={[styles.tabText, s.id === storeId && styles.tabTextActive]}>{s.name}</Text>
            </Pressable>
          ))}
        </View>
        <View style={styles.help}>
          <Icon name="information-circle-outline" size={16} color={colors.textSoft} />
          <Text style={[type.small, { flex: 1 }]}>Avaa oikean tuotteen sivu ja paina "Lue tiedot".</Text>
        </View>
      </View>
      <RefWebView
        key={storeId}
        ref={web}
        source={{ uri: store.searchUrl(query) }}
        style={{ flex: 1 }}
        startInLoadingState
        renderLoading={() => <ActivityIndicator color={colors.primary} style={StyleSheet.absoluteFill} />}
        onMessage={(e: WebViewMessageEvent) => {
          setReading(false);
          const message = parseMessage(e, storeId);
          if (message.type === 'product' && (message.ingredients || message.nutritionText)) onFound(message);
          else Alert.alert('Tietoja ei löytynyt', 'Avaa ensin tuotteen oma sivu ja yritä uudelleen.');
        }}
      />
      <View style={styles.bar}>
        <Button label={reading ? 'Luetaan…' : 'Lue tiedot'} icon="download-outline" onPress={read} disabled={reading} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  top: { paddingHorizontal: space.lg, paddingBottom: space.sm, gap: space.sm, backgroundColor: colors.background },
  back: { flexDirection: 'row', alignItems: 'center', gap: 2, marginLeft: -4, alignSelf: 'flex-start' },
  backText: { fontSize: 16, color: colors.primary, fontWeight: '600' },
  segment: { flexDirection: 'row', backgroundColor: colors.surfaceAlt, borderRadius: radius.md, padding: 3 },
  tab: { flex: 1, paddingVertical: 9, alignItems: 'center', borderRadius: radius.sm },
  tabActive: { backgroundColor: colors.surface, shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1 },
  tabText: { fontSize: 14, color: colors.textSoft, fontWeight: '600' },
  tabTextActive: { color: colors.text, fontWeight: '700' },
  help: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  bar: { padding: space.md, backgroundColor: colors.surface, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.border },
});
