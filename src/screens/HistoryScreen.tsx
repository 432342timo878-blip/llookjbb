import { useEffect, useState } from 'react';
import { SectionList, StyleSheet, Text, View } from 'react-native';

import { getHistory, HistoryItem, Override } from '../storage';
import { colors, radius, space, type, VERDICT_STYLE } from '../theme';
import { EmptyState, Icon, IconCircle, ListRow, ScreenTitle, SearchField } from '../ui';

interface Props {
  overrides: Record<string, Override>;
  onOpen: (item: HistoryItem) => void;
}

const timeFormat = new Intl.DateTimeFormat('fi-FI', { hour: '2-digit', minute: '2-digit' });
const dayFormat = new Intl.DateTimeFormat('fi-FI', { weekday: 'long', day: 'numeric', month: 'numeric' });

function dayLabel(ts: number, now = new Date()): string {
  const d = new Date(ts);
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  if (ts >= startOfToday) return 'Tänään';
  if (ts >= startOfToday - 86400000) return 'Eilen';
  const label = dayFormat.format(d);
  return label.charAt(0).toUpperCase() + label.slice(1);
}

export function HistoryScreen({ overrides, onOpen }: Props) {
  const [items, setItems] = useState<HistoryItem[]>([]);
  const [query, setQuery] = useState('');

  useEffect(() => {
    getHistory().then(setItems);
  }, []);

  const q = query.trim().toLowerCase();
  const visible = q ? items.filter((i) => `${i.name} ${i.brand ?? ''} ${i.barcode}`.toLowerCase().includes(q)) : items;

  // Ryhmitellään päivän mukaan (historia on jo uusimmasta vanhimpaan).
  const sections: { title: string; data: HistoryItem[] }[] = [];
  for (const item of visible) {
    const title = dayLabel(item.scannedAt);
    const last = sections[sections.length - 1];
    if (last?.title === title) last.data.push(item);
    else sections.push({ title, data: [item] });
  }

  return (
    <SectionList
      sections={sections}
      keyExtractor={(i) => i.barcode}
      contentContainerStyle={styles.container}
      stickySectionHeadersEnabled={false}
      keyboardShouldPersistTaps="handled"
      ListHeaderComponent={
        <View style={{ gap: space.lg, marginBottom: space.sm }}>
          <ScreenTitle title="Historia" subtitle={items.length > 0 ? `${items.length} skannattua tuotetta` : undefined} />
          {items.length > 0 && <SearchField value={query} onChange={setQuery} placeholder="Hae nimellä tai viivakoodilla" />}
        </View>
      }
      ListEmptyComponent={
        items.length === 0 ? (
          <EmptyState icon="time-outline" title="Ei vielä skannauksia" body="Skannatut tuotteet ja niiden tulokset tallentuvat tänne." />
        ) : (
          <Text style={[type.body, { textAlign: 'center', marginTop: space.xl }]}>Ei osumia.</Text>
        )
      }
      renderSectionHeader={({ section }) => <Text style={[type.label, styles.sectionHeader]}>{section.title}</Text>}
      renderItem={({ item, index, section }) => {
        const v = VERDICT_STYLE[item.verdict];
        const override = overrides[item.barcode];
        const first = index === 0;
        const last = index === section.data.length - 1;
        return (
          <View style={[styles.rowWrap, first && styles.rowFirst, last && styles.rowLast]}>
            <ListRow
              title={item.name}
              subtitle={[item.brand, timeFormat.format(new Date(item.scannedAt))].filter(Boolean).join(' · ')}
              leading={<IconCircle name={v.icon} color={v.color} bg={v.bg} size={36} />}
              trailing={
                <View style={styles.trailing}>
                  {override && <Icon name={override === 'ok' ? 'thumbs-up' : 'thumbs-down'} size={16} color={override === 'ok' ? colors.green : colors.red} />}
                  <Icon name="chevron-forward" size={18} color={colors.muted} />
                </View>
              }
              onPress={() => onOpen(item)}
              last={last}
            />
          </View>
        );
      }}
    />
  );
}

const styles = StyleSheet.create({
  container: { paddingHorizontal: space.xl, paddingBottom: space.xxl },
  sectionHeader: { marginTop: space.lg, marginBottom: space.sm },
  // Saman päivän rivit muodostavat yhden kortin.
  rowWrap: { backgroundColor: colors.surface, paddingHorizontal: space.lg, borderLeftWidth: 1, borderRightWidth: 1, borderColor: colors.border },
  rowFirst: { borderTopWidth: 1, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, paddingTop: 2 },
  rowLast: { borderBottomWidth: 1, borderBottomLeftRadius: radius.lg, borderBottomRightRadius: radius.lg, paddingBottom: 2 },
  trailing: { flexDirection: 'row', alignItems: 'center', gap: space.sm },
});
