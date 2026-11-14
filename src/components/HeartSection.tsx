import { Pressable, StyleSheet, Text, View } from 'react-native';

import { HeartAssessment, RuleStatus } from '../analysis/heartCriteria';
import { colors, IconName, radius, space, type } from '../theme';
import { Card, Icon, IconCircle, SectionLabel } from '../ui';
import { Button } from './Button';

interface Props {
  /** Mistä virallinen Sydänmerkki pääteltiin, tai null jos merkkiä ei löytynyt. */
  officialSource: string | null;
  assessment?: HeartAssessment;
  /** Tuoteryhmä on käyttäjän valitsema eikä pääteltu. */
  groupChosenByUser: boolean;
  onChangeGroup?: () => void;
  onPhotographNutrition?: () => void;
}

const STATUS: Record<HeartAssessment['status'], { icon: IconName; text: string; color: string; bg: string }> = {
  eligible: { icon: 'heart', text: 'Täyttää Sydänmerkin kriteerit', color: colors.heart, bg: colors.redBg },
  notEligible: { icon: 'close', text: 'Ei täytä Sydänmerkin kriteerejä', color: colors.textSoft, bg: colors.surfaceAlt },
  unknown: { icon: 'help', text: 'Ei voida arvioida kokonaan', color: colors.yellow, bg: colors.yellowBg },
  excluded: { icon: 'remove', text: 'Tuoteryhmä ei voi saada Sydänmerkkiä', color: colors.grey, bg: colors.greyBg },
};

const RULE_ICON: Record<RuleStatus, { icon: IconName; color: string }> = {
  pass: { icon: 'checkmark-circle', color: colors.green },
  fail: { icon: 'close-circle', color: colors.red },
  unknown: { icon: 'help-circle', color: colors.yellow },
};

export function HeartSection({ officialSource, assessment, groupChosenByUser, onChangeGroup, onPhotographNutrition }: Props) {
  const missingValues = assessment?.results.some((r) => r.status === 'unknown' && r.detail.includes('puuttuu') && !r.label.startsWith('Ei lisättyä'));
  const status = assessment ? STATUS[assessment.status] : undefined;

  return (
    <View>
      <SectionLabel>Sydänmerkki</SectionLabel>
      <Card style={{ gap: space.md }}>
        {officialSource && (
          <View style={styles.official}>
            <Icon name="heart" size={18} color={colors.heart} />
            <View style={{ flex: 1 }}>
              <Text style={[type.bodyStrong, { color: colors.heart }]}>Tuotteella on Sydänmerkki</Text>
              <Text style={type.small}>{officialSource}</Text>
            </View>
          </View>
        )}

        {assessment && status ? (
          <>
            <View style={styles.statusRow}>
              <IconCircle name={status.icon} color={status.color} bg={status.bg} size={40} />
              <View style={{ flex: 1 }}>
                <Text style={[type.heading, { color: status.color === colors.textSoft ? colors.text : status.color }]}>{status.text}</Text>
                <Text style={type.small}>
                  {assessment.group.name}
                  {groupChosenByUser ? '' : ' (arvio)'}
                </Text>
              </View>
            </View>
            {onChangeGroup && (
              <Pressable onPress={onChangeGroup} style={styles.change} hitSlop={8}>
                <Icon name="swap-horizontal" size={16} color={colors.primary} />
                <Text style={styles.changeText}>Vaihda tuoteryhmä</Text>
              </Pressable>
            )}

            {assessment.group.excluded && <Text style={type.small}>{assessment.group.excluded}</Text>}

            {assessment.results.length > 0 && (
              <View style={styles.rules}>
                {assessment.results.map((r, i) => (
                  <View key={i} style={styles.rule}>
                    <Icon name={RULE_ICON[r.status].icon} size={18} color={RULE_ICON[r.status].color} />
                    <View style={{ flex: 1 }}>
                      <Text style={type.bodyStrong}>{r.label}</Text>
                      <Text style={type.small}>{r.detail}</Text>
                    </View>
                  </View>
                ))}
              </View>
            )}
            {assessment.group.note && <Text style={type.small}>{assessment.group.note}</Text>}
          </>
        ) : (
          <View style={{ gap: space.sm }}>
            <Text style={type.body}>Tuoteryhmää ei tunnistettu.</Text>
            {onChangeGroup && <Button label="Valitse tuoteryhmä" icon="list" variant="secondary" onPress={onChangeGroup} />}
          </View>
        )}

        {missingValues && onPhotographNutrition && (
          <Button label="Kuvaa ravintoarvotaulukko" icon="camera-outline" variant="secondary" onPress={onPhotographNutrition} />
        )}
        <Text style={type.small}>Arvio perustuu Sydänmerkin julkisiin tuoteryhmäkriteereihin (per 100 g). Se ei ole virallinen merkki.</Text>
      </Card>
    </View>
  );
}

const styles = StyleSheet.create({
  official: { flexDirection: 'row', gap: space.md, alignItems: 'center', backgroundColor: colors.redBg, borderRadius: radius.md, padding: space.md },
  statusRow: { flexDirection: 'row', alignItems: 'center', gap: space.md },
  change: { flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start' },
  changeText: { fontSize: 14, fontWeight: '700', color: colors.primary },
  rules: { gap: space.md, backgroundColor: colors.surfaceAlt, borderRadius: radius.md, padding: space.md },
  rule: { flexDirection: 'row', gap: space.sm, alignItems: 'flex-start' },
});
