import { render, screen } from '@testing-library/react'
import Page from './page'

describe('Home Page', () => {
  it('renders headline', () => {
    render(<Page />)
    expect(screen.getByText('Basket Coach')).toBeInTheDocument()
  })
})