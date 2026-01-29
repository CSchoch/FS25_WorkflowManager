import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  icon: string;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Seamless Integration',
    icon: '🔗',
    description: (
      <>
        Combines AutoDrive navigation with Courseplay field work into unified
        workflows. No more manual switching between mods.
      </>
    ),
  },
  {
    title: 'Visual Workflow Editor',
    icon: '📝',
    description: (
      <>
        Create and manage workflows through an intuitive GUI. Add, edit, and
        reorder steps with a simple tabular interface.
      </>
    ),
  },
  {
    title: 'In-Vehicle Controls',
    icon: '🚜',
    description: (
      <>
        Control your workflows directly from the vehicle HUD. Pause, resume,
        skip steps, or stop execution without opening menus.
      </>
    ),
  },
];

function Feature({title, icon, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <span style={{fontSize: '4rem'}}>{icon}</span>
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
