// Sovelluksen yhteiset rakennuspalikat, jotta kaikki näkymät näyttävät samalta.
import Ionicons from '@expo/vector-icons/Ionicons';
import { ReactNode } from 'react';
import { Pressable, StyleProp, StyleSheet, Text, TextInput, View, ViewStyle } from 'react-native';

import { colors, IconName, radius, space, type } from '../theme';

export function Icon({ name, size = 20, color = colors.text }: { name: IconName; size?: number; color?: string }) {
  return <Ionicons name={name} size={size} color={color} />;
}

/** Näkymän iso otsikko, valinnainen alaotsikko ja paluu-painike. */
export function ScreenTitle({ title, subtitle, onBack, right }: { title: string; subtitle?: string; onBack?: () => void; right?: ReactNode }) {
  return (
    <View style={styles.titleWrap}>
      {onBack && (
        <Pressable onPress={onBack} hitSlop={12} style={styles.back}>
          <Icon name="chevron-back" size={22} color={colors.primary} />
          <Text style={styles.backText}>Takaisin</Text>
        </Pressable>
      )}
      <View style={styles.titleRow}>
        <Text style={[type.display, { flex: 1 }]}>{title}</Text>
        {right}
      </View>
      {subtitle ? <Text style={[type.body, { marginTop: 2 }]}>{subtitle}</Text> : null}
    </View>
  );
}

export function Card({ children, style, tint }: { children: ReactNode; style?: StyleProp<ViewStyle>; tint?: string }) {
  return <View style={[styles.card, tint ? { backgroundColor: tint, borderColor: 'transparent' } : null, style]}>{children}</View>;
}

export function SectionLabel({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return (
    <View style={[{ marginBottom: space.sm, marginTop: space.xs }, style]}>
      <Text style={type.label}>{children}</Text>
    </View>
  );
}

export function Pill({ label, color = colors.textSoft, bg = colors.surfaceAlt, icon }: { label: string; color?: string; bg?: string; icon?: IconName }) {
  return (
    <View style={[styles.pill, { backgroundColor: bg }]}>
      {icon && <Icon name={icon} size={12} color={color} />}
      <Text style={[styles.pillText, { color }]}>{label}</Text>
    </View>
  );
}

/** Pyöreä ikonipohja, esim. tuomion tai listarivin alussa. */
export function IconCircle({ name, color, bg, size = 40 }: { name: IconName; color: string; bg: string; size?: number }) {
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: bg, alignItems: 'center', justifyContent: 'center' }}>
      <Icon name={name} size={Math.round(size * 0.5)} color={color} />
    </View>
  );
}

export function ListRow({
  title,
  subtitle,
  leading,
  trailing,
  onPress,
  last,
}: {
  title: string;
  subtitle?: string;
  leading?: ReactNode;
  trailing?: ReactNode;
  onPress?: () => void;
  last?: boolean;
}) {
  const content = (
    <View style={[styles.row, !last && styles.rowDivider]}>
      {leading}
      <View style={{ flex: 1 }}>
        <Text style={type.bodyStrong} numberOfLines={2}>
          {title}
        </Text>
        {subtitle ? (
          <Text style={[type.small, { marginTop: 2 }]} numberOfLines={2}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {trailing ?? (onPress ? <Icon name="chevron-forward" size={18} color={colors.muted} /> : null)}
    </View>
  );
  return onPress ? (
    <Pressable onPress={onPress} style={({ pressed }) => pressed && { opacity: 0.6 }}>
      {content}
    </Pressable>
  ) : (
    content
  );
}

/** Värillinen huomautus ikonilla (varoitukset, vinkit). */
export function Notice({ icon, color, bg, children }: { icon: IconName; color: string; bg: string; children: ReactNode }) {
  return (
    <View style={[styles.notice, { backgroundColor: bg }]}>
      <Icon name={icon} size={18} color={color} />
      <Text style={[type.body, { flex: 1, color: colors.text }]}>{children}</Text>
    </View>
  );
}

/** Hakukenttä suurennuslasilla ja tyhjennyspainikkeella. */
export function SearchField({ value, onChange, placeholder }: { value: string; onChange: (t: string) => void; placeholder: string }) {
  return (
    <View style={styles.search}>
      <Icon name="search" size={18} color={colors.muted} />
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor={colors.muted}
        style={styles.searchInput}
        returnKeyType="search"
      />
      {value.length > 0 && (
        <Pressable onPress={() => onChange('')} hitSlop={10}>
          <Icon name="close-circle" size={18} color={colors.muted} />
        </Pressable>
      )}
    </View>
  );
}

/** Tyhjä tila: ikoni, otsikko ja selitys. */
export function EmptyState({ icon, title, body }: { icon: IconName; title: string; body: string }) {
  return (
    <View style={styles.empty}>
      <IconCircle name={icon} color={colors.primary} bg={colors.primarySoft} size={56} />
      <Text style={[type.heading, { textAlign: 'center' }]}>{title}</Text>
      <Text style={[type.body, { textAlign: 'center' }]}>{body}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  search: { flexDirection: 'row', alignItems: 'center', gap: space.sm, backgroundColor: colors.surface, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingHorizontal: space.md, height: 48 },
  searchInput: { flex: 1, fontSize: 16, color: colors.text, height: '100%' },
  empty: { alignItems: 'center', gap: space.sm, paddingVertical: space.xxl, paddingHorizontal: space.xl },
  titleWrap: { paddingTop: space.sm, paddingBottom: space.lg },
  titleRow: { flexDirection: 'row', alignItems: 'center', gap: space.md },
  back: { flexDirection: 'row', alignItems: 'center', gap: 2, marginBottom: space.sm, marginLeft: -4, alignSelf: 'flex-start' },
  backText: { fontSize: 16, color: colors.primary, fontWeight: '600' },
  card: { backgroundColor: colors.surface, borderRadius: radius.lg, padding: space.lg, borderWidth: 1, borderColor: colors.border },
  pill: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.pill, alignSelf: 'flex-start' },
  pillText: { fontSize: 12, fontWeight: '600' },
  row: { flexDirection: 'row', alignItems: 'center', gap: space.md, paddingVertical: space.md },
  rowDivider: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: colors.border },
  notice: { flexDirection: 'row', gap: space.md, padding: space.md, borderRadius: radius.md, alignItems: 'flex-start' },
});
