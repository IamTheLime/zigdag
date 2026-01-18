import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import {
  faDownload,
  faKeyboard,
  faHashtag,
  faQuoteLeft,
  faCodeBranch,
  faPlus,
  faMinus,
  faXmark,
  faDivide,
  faSuperscript,
  faPercent,
  faBars,
  faSquareRootAlt,
  faChartLine,
  faWaveSquare,
  faArrowUp,
  faArrowDown,
  faCalculator,
  faArrowsAltH,
  faBullseye,
} from '@fortawesome/free-solid-svg-icons';

const iconMap = {
  'arrow-down-to-bracket': faDownload,
  'keyboard': faKeyboard,
  'hashtag': faHashtag,
  'quote-left': faQuoteLeft,
  'code-branch': faCodeBranch,
  'plus': faPlus,
  'minus': faMinus,
  'xmark': faXmark,
  'divide': faDivide,
  'superscript': faSuperscript,
  'percent': faPercent,
  'bars': faBars,
  'square-root-variable': faSquareRootAlt,
  'chart-line': faChartLine,
  'wave-square': faWaveSquare,
  'arrow-up': faArrowUp,
  'arrow-down': faArrowDown,
  'sigma': faCalculator,
  'arrows-left-right': faArrowsAltH,
  'bullseye': faBullseye,
};

interface NodeIconProps {
  icon?: string;
  className?: string;
}

export function NodeIcon({ icon, className = '' }: NodeIconProps) {
  if (!icon) return null;
  
  const faIcon = iconMap[icon as keyof typeof iconMap];
  if (!faIcon) return null;
  
  return <FontAwesomeIcon icon={faIcon} className={className} />;
}
