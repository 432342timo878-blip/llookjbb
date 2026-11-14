import type { ComponentProps } from 'react';
import type Ionicons from '@expo/vector-icons/Ionicons';

import { Severity, Verdict } from './analysis/analyze';

export type IconName = ComponentProps<typeof Ionicons>['name'];

// Lämmin, rauhallinen paletti: paperinvalkoinen tausta, yksi syvä metsänvihreä pääväri.
export const colors = {
  background: '#F5F3EE',
  surface: '#FFFFFF',
  surfaceAlt: '#EFEDE7',
  text: '#16201B',
  textSoft: '#3E4A43',
  muted: '#6E7871',
  border: '#E4E1D9',
  primary: '#1E5B43',
  primarySoft: '#E3EFE8',
  primaryText: '#FFFFFF',
  green: '#2E7D52',
  greenBg: '#E3F1E8',
  yellow: '#A86A12',
  yellowBg: '#FAF0DB',
  red: '#B83A2B',
  redBg: '#F8E5E1',
  grey: '#6B7280',
  greyBg: '#ECEDEF',
  heart: '#C8364B',
};

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 };
export const radius = { sm: 10, md: 14, lg: 20, pill: 999 };

export const type = {
  display: { fontSize: 30, fontWeight: '800' as const, letterSpacing: -0.5, color: colors.text },
  title: { fontSize: 22, fontWeight: '700' as const, letterSpacing: -0.3, color: colors.text },
  heading: { fontSize: 17, fontWeight: '700' as const, color: colors.text },
  body: { fontSize: 15, lineHeight: 21, color: colors.textSoft },
  bodyStrong: { fontSize: 15, fontWeight: '600' as const, color: colors.text },
  small: { fontSize: 13, lineHeight: 18, color: colors.muted },
  label: { fontSize: 12, fontWeight: '700' as const, letterSpacing: 0.8, textTransform: 'uppercase' as const, color: colors.muted },
};

export const VERDICT_STYLE: Record<Verdict, { color: string; bg: string; title: string; subtitle: string; icon: IconName }> = {
  green: {
    color: colors.green,
    bg: colors.greenBg,
    icon: 'checkmark',
    title: 'Sopii todennäköisesti',
    subtitle: 'Ei tunnettuja runsas-FODMAP-ainesosia.',
  },
  yellow: {
    color: colors.yellow,
    bg: colors.yellowBg,
    icon: 'alert',
    title: 'Varo – annoskoko ratkaisee',
    subtitle: 'Sisältää kohtalaisia tai epävarmoja ainesosia.',
  },
  red: {
    color: colors.red,
    bg: colors.redBg,
    icon: 'close',
    title: 'Ei sovi – runsas-FODMAP',
    subtitle: 'Sisältää ainesosia, jotka aiheuttavat usein oireita.',
  },
  unknown: {
    color: colors.grey,
    bg: colors.greyBg,
    icon: 'help',
    title: 'Ei ainesosatietoja',
    subtitle: 'Kuvaa tai kirjoita ainesosaluettelo pakkauksesta, niin tarkistan sen.',
  },
};

export const SEVERITY_COLOR: Record<Severity, string> = {
  bad: colors.red,
  caution: colors.yellow,
  ok: colors.green,
};

export const SEVERITY_BG: Record<Severity, string> = {
  bad: colors.redBg,
  caution: colors.yellowBg,
  ok: colors.greenBg,
};
