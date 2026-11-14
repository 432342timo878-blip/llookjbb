import { Pressable, StyleProp, StyleSheet, Text, View, ViewStyle } from 'react-native';

import { colors, IconName, radius } from '../theme';
import { Icon } from '../ui';

interface Props {
  label: string;
  onPress: () => void;
  /** primary: täytetty pääväri. secondary: valkoinen reunuksella. ghost: pelkkä teksti. */
  variant?: 'primary' | 'secondary' | 'ghost';
  icon?: IconName;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function Button({ label, onPress, variant = 'primary', icon, disabled, style }: Props) {
  const fg = variant === 'primary' ? colors.primaryText : colors.primary;
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [styles.button, styles[variant], (pressed || disabled) && { opacity: 0.55 }, style]}
    >
      <View style={styles.inner}>
        {icon && <Icon name={icon} size={19} color={fg} />}
        <Text style={[styles.label, { color: fg }]} numberOfLines={1}>
          {label}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { minHeight: 52, paddingHorizontal: 18, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center' },
  inner: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  primary: { backgroundColor: colors.primary },
  secondary: { backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border },
  ghost: { backgroundColor: 'transparent', minHeight: 44 },
  label: { fontSize: 16, fontWeight: '700' },
});
