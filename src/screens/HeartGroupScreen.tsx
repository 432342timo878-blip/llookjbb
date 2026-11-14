import { SectionList, StyleSheet, Text, View } from 'react-native';

import { HEART_GROUPS } from '../analysis/heartCriteria';
import { Button } from '../components/Button';
import { colors, radius, space, type } from '../theme';
import { Icon, ListRow, ScreenTitle } from '../ui';

interface Props {
  selected?: string;
  onSelect: (groupId: string | null) => void;
  onCancel: () => void;
}

const SECTIONS = [...new Set(HEART_GROUPS.map((g) => g.category))].map((category) => ({
  title: category,
  data: HEART_GROUPS.filter((g) => g.category === category),
}));

/** Sydänmerkki-tuoteryhmän valinta, kun arvio osui väärin. */
export function HeartGroupScreen({ selected, onSelect, onCancel }: Props) {
  return (
    <SectionList
      sections={SECTIONS}
      keyExtractor={(g) => g.id}
      contentContainerStyle={styles.container}
      stickySectionHeadersEnabled={false}
      ListHeaderComponent={
        <View style={{ gap: space.md }}>
          <ScreenTitle title="Tuoteryhmä" subtitle="Valitse tuotteelle oikea Sydänmerkki-tuoteryhmä." onBack={onCancel} />
          {selected && <Button label="Palauta automaattinen arvio" icon="refresh" variant="secondary" onPress={() => onSelect(null)} />}
        </View>
      }
      renderSectionHeader={({ section }) => <Text style={[type.label, styles.header]}>{section.title}</Text>}
      renderItem={({ item, index, section }) => {
        const first = index === 0;
        const last = index === section.data.length - 1;
        const isSelected = item.id === selected;
        return (
          <View style={[styles.rowWrap, first && styles.rowFirst, last && styles.rowLast]}>
            <ListRow
              title={item.name}
              subtitle={item.excluded ? 'Ei voi saada Sydänmerkkiä' : undefined}
              trailing={isSelected ? <Icon name="checkmark-circle" size={22} color={colors.primary} /> : <View style={styles.radio} />}
              onPress={() => onSelect(item.id)}
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
  header: { marginTop: space.xl, marginBottom: space.sm },
  rowWrap: { backgroundColor: colors.surface, paddingHorizontal: space.lg, borderLeftWidth: 1, borderRightWidth: 1, borderColor: colors.border },
  rowFirst: { borderTopWidth: 1, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg },
  rowLast: { borderBottomWidth: 1, borderBottomLeftRadius: radius.lg, borderBottomRightRadius: radius.lg },
  radio: { width: 20, height: 20, borderRadius: 10, borderWidth: 2, borderColor: colors.border },
});
